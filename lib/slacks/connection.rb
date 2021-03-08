require "slacks/bot_user"
require "slacks/channel"
require "slacks/driver"
require "slacks/observer"
require "slacks/errors"
require "slacks/guest_channel"
require "slacks/team"
require "slacks/user"
require "faraday"

module Slacks
  class Connection
    include ::Slacks::Observer

    attr_reader :team, :bot, :token
    attr_accessor :typing_speed

    def initialize(token, options={})
      raise ArgumentError, "Missing required parameter: 'token'" if token.nil? or token.empty?
      @token = token
      @typing_speed = options.fetch(:typing_speed, 100.0)

      @user_ids_dm_ids = {}
      @users_by_id = {}
      @user_id_by_name = {}
      @conversations_by_id = {}
      @conversation_ids_by_name = {}
    end



    def send_message(message, options={})
      channel = options.fetch(:channel) { raise ArgumentError, "Missing parameter :channel" }
      attachments = Array(options[:attachments])
      params = {
        channel: to_channel_id(channel),
        text: message,
        as_user: true, # post as the authenticated user (rather than as slackbot)
        link_names: 1} # find and link channel names and user names
      params.merge!(attachments: MultiJson.dump(attachments)) if attachments.any?
      params.merge!(options.select { |key, _| SEND_MESSAGE_PARAMS.member?(key) })
      api("chat.postMessage", **params)
    end
    alias :say :send_message

    def get_message(channel, ts)
      params = {
        channel: to_channel_id(channel),
        timestamp: ts }
      api("reactions.get", **params)
    end

    def update_message(ts, message, options={})
      channel = options.fetch(:channel) { raise ArgumentError, "Missing parameter :channel" }
      attachments = Array(options[:attachments])
      params = {
        ts: ts,
        channel: to_channel_id(channel),
        text: message,
        as_user: true, # post as the authenticated user (rather than as slackbot)
        link_names: 1} # find and link channel names and user names
      params.merge!(attachments: MultiJson.dump(attachments)) if attachments.any?
      params.merge!(options.select { |key, _| [:username, :as_user, :parse, :link_names,
        :unfurl_links, :unfurl_media, :icon_url, :icon_emoji].member?(key) })
      api("chat.update", **params)
    end

    def add_reaction(emojis, message)
      Array(emojis).each do |emoji|
        api("reactions.add",
          name: emoji.gsub(/^:|:$/, ""),
          channel: message.channel.id,
          timestamp: message.timestamp)
      end
    end



    def typing_on(channel)
      raise NotListeningError unless listening?
      websocket.write MultiJson.dump(type: "typing", channel: to_channel_id(channel))
    end

    def ping
      raise NotListeningError unless listening?
      websocket.ping
    end

    def listening?
      !websocket.nil?
    end



    def listen!
      response = api("rtm.start")
      store_context!(response)

      @websocket = Slacks::Driver.new
      websocket.connect_to websocket_url
      trigger "connected"

      websocket.on(:error) do |event|
        raise ConnectionError.new(event)
      end

      websocket.on(:message) do |data|
        case data["type"]
        when NilClass
          # Every event has a `type` property:
          # https://api.slack.com/rtm#events
          # If an event comes across without
          # one, we'll skill it.
          next

        when EVENT_GROUP_JOINED, EVENT_CHANNEL_CREATED
          conversation = data["channel"]
          @conversations_by_id[conversation["id"]] = conversation
          @conversation_ids_by_name[conversation["name"]] = conversation["id"]

        when EVENT_USER_JOINED
          user = data["user"]
          @users_by_id[user["id"]] = user
          @user_id_by_name[user["name"]] = user["id"]

        when EVENT_MESSAGE
          # Don't respond to things that this bot said
          next if data["user"] == bot.id
          # ...or to messages with no text
          next if data["text"].nil? || data["text"].empty?
        end

        trigger data["type"], data
      end

      websocket.main_loop

    rescue EOFError
      # Slack hung up on us, we'll ask for a new WebSocket URL and reconnect.
      trigger "error", "Websocket Driver received EOF; reconnecting"
      retry
    end

    EVENT_CHANNEL_CREATED = "channel_created".freeze
    EVENT_GROUP_JOINED = "group_joined".freeze
    EVENT_MESSAGE = "message".freeze
    EVENT_USER_JOINED = "team_join".freeze



    def channels
      channels = user_id_by_name.keys + conversation_ids_by_name.keys
      if channels.empty?
        fetch_conversations!
        fetch_users!
      end
      channels
    end

    def can_see?(channel)
      channel_id = to_channel_id(channel)
      channel_id && !channel_id.empty?
    rescue ArgumentError
      false
    end



    def find_channel(id)
      case id
      when /^U/ then find_user(id)
      when /^D/
        user = find_user(get_user_id_for_dm(id))
        Slacks::Channel.new self, {
          "id" => id,
          "is_im" => true,
          "name" => user.username }
      else
        Slacks::Channel.new(self, find_conversation(id))
      end
    end

    def find_conversation(id)
      conversations_by_id.fetch(id) do
        fetch_conversations!
        conversations_by_id.fetch(id) do
          raise ArgumentError, "Unable to find a conversation with the ID #{id.inspect}"
        end
      end
    end

    def find_user(id)
      user = users_by_id.fetch(id) do
        fetch_users!
        users_by_id.fetch(id) do
          raise ArgumentError, "Unable to find a user with the ID #{id.inspect}"
        end
      end
      Slacks::User.new(self, user)
    end

    def find_user_by_nickname(nickname)
      find_user to_user_id(nickname)
    end



    def user_exists?(username)
      return false if username.nil?
      user_id = to_user_id(username)
      user_id && !user_id.empty?
    rescue ArgumentError
      false
    end

    def users
      fetch_users! if @users_by_id.empty?
      @users_by_id.values
    end



  private
    attr_reader :user_ids_dm_ids,
                :users_by_id,
                :user_id_by_name,
                :conversations_by_id,
                :conversation_ids_by_name,
                :websocket_url,
                :websocket



    def store_context!(response)
      @websocket_url = response.fetch("url")
      @bot = BotUser.new(response.fetch("self"))
      @team = Team.new(response.fetch("team"))

      @conversations_by_id = Hash[response.fetch("channels").map { |attrs| [ attrs.fetch("id"), attrs ] }]
      @conversation_ids_by_name = Hash[response.fetch("channels").map { |attrs| [ attrs["name"], attrs["id"] ] }]
    end



    def to_channel_id(name)
      return name.id if name.is_a?(Slacks::Channel)
      return name if name =~ /^[DGC]/ # this already looks like a channel id
      return get_dm_for_username(name) if name.start_with?("@")

      name = name.gsub(/^#/, "") # Leading hashes are no longer a thing in the conversations API
      conversation_ids_by_name[name] || fetch_conversations![name] || missing_conversation!(name)
    end

    def to_user_id(name)
      user_id_by_name[name] || fetch_users![name] || missing_user!(name)
    end

    def get_dm_for_username(name)
      get_dm_for_user_id to_user_id(name)
    end

    def get_dm_for_user_id(user_id)
      user_ids_dm_ids[user_id] ||= begin
        response = api("conversations.open", users: user_id)
        response["channel"]["id"]
      end
    end


    def fetch_conversations!
      conversations, ims = api("conversations.list", types: "public_channel,private_channel,mpim,im")["channels"].partition { |attrs| attrs["is_channel"] || attrs["is_group"] }
      user_ids_dm_ids.merge! Hash[ims.map { |attrs| attrs.values_at("user", "id") }]
      @conversations_by_id = Hash[conversations.map { |attrs| [ attrs.fetch("id"), attrs ] }]
      @conversation_ids_by_name = Hash[conversations.map { |attrs| [ attrs["name"], attrs["id"] ] }]
    end

    def fetch_users!
      response = api("users.list")
      @users_by_id = response["members"].each_with_object({}) { |attrs, hash| hash[attrs["id"]] = attrs }
      @user_id_by_name = Hash[response["members"].map { |attrs| ["@#{attrs["name"]}", attrs["id"]] }]
    end



    def missing_conversation!(name)
      raise ArgumentError, "Couldn't find a conversation named #{name}"
    end

    def missing_user!(name)
      raise ArgumentError, "Couldn't find a user named #{name}"
    end



    def get_user_id_for_dm(dm)
      user_id = user_ids_dm_ids.key(dm)
      unless user_id
        fetch_conversations!
        user_id = user_ids_dm_ids.key(dm)
      end
      raise ArgumentError, "Unable to find a user for the direct message ID #{dm.inspect}" unless user_id
      user_id
    end



    def api(command, page_limit: MAX_PAGES, **params)
      params_with_token = params.merge(token: token)
      response = api_post command, params_with_token
      fetched_pages = 1
      cursor = response.dig("response_metadata", "next_cursor")
      while cursor && !cursor.empty? && fetched_pages < page_limit do
        api_post(command, params_with_token.merge(cursor: cursor)).each do |key, value|
          if value.is_a?(Array)
            response[key].concat value
          elsif value.is_a?(Hash)
            response[key].merge! value
          else
            response[key] = value
          end
        end
        fetched_pages += 1
        cursor = response.dig("response_metadata", "next_cursor")
      end
      response
    end

    def api_post(command, params)
      response = http.post(command, params)
      response = MultiJson.load(response.body)
      unless response["ok"]
        response["error"].split(/,\s*/).each do |error_code|
          raise ::Slacks::Response.fetch(error_code).new(command, params, response)
        end
      end
      response

    rescue MultiJson::ParseError
      $!.additional_information[:response_body] = response.body
      $!.additional_information[:response_status] = response.status
      raise
    end

    def http
      @http ||= Faraday.new(url: "https://slack.com/api").tap do |connection|
        connection.response :raise_error
      end
    end



    SEND_MESSAGE_PARAMS = %i{
      username
      as_user
      parse
      link_names
      unfurl_links
      unfurl_media
      icon_url
      icon_emoji
      thread_ts
      reply_broadcast
    }.freeze

    MAX_PAGES = 9001

  end
end
