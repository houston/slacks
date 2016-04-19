require "slacks/bot_user"
require "slacks/team"
require "slacks/channel"
require "slacks/guest_channel"
require "slacks/conversation"
require "slacks/driver"
require "slacks/rtm_event"
require "slacks/listener"
require "slacks/message"
require "slacks/user"
require "slacks/errors"
require "faraday"
require "faraday/raise_errors"

module Slacks
  class Connection
    attr_reader :team, :bot, :token

    EVENT_MESSAGE = "message".freeze
    EVENT_GROUP_JOINED = "group_joined".freeze
    EVENT_USER_JOINED = "team_join".freeze

    def initialize(session, token)
      @user_ids_dm_ids = {}
      @users_by_id = {}
      @user_id_by_name = {}
      @groups_by_id = {}
      @group_id_by_name = {}
      @channels_by_id = {}
      @channel_id_by_name = {}

      @session = session
      @token = token
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
      params.merge!(options.select { |key, _| [:username, :as_user, :parse, :link_names,
        :unfurl_links, :unfurl_media, :icon_url, :icon_emoji].member?(key) })
      api("chat.postMessage", params)
    end

    def add_reaction(emojis, message)
      Array(emojis).each do |emoji|
        api("reactions.add", {
          name: emoji.gsub(/^:|:$/, ""),
          channel: message.channel.id,
          timestamp: message.timestamp })
      end
    end



    def listen!
      response = api("rtm.start")

      unless response["ok"]
        raise MigrationInProgress if response["error"] == "migration_in_progress"
        raise ResponseError.new(response, response["error"])
      end

      store_context!(response)

      client = Slacks::Driver.new
      client.connect_to websocket_url

      client.on(:error) do |event|
        raise ConnectionError.new(event)
      end

      client.on(:message) do |data|
        case data["type"]
        when EVENT_GROUP_JOINED
          group = data["channel"]
          @groups_by_id[group["id"]] = group
          @group_id_by_name[group["name"]] = group["id"]

        when EVENT_USER_JOINED
          user = data["user"]
          @users_by_id[user["id"]] = user
          @user_id_by_name[user["name"]] = user["id"]

        when EVENT_MESSAGE
          # Don't respond to things that this bot said
          next if data["user"] == bot.id
          # ...or to messages with no text
          next if data["text"].nil? || data["text"].empty?
          yield data
        end
      end

      client.main_loop

    rescue EOFError
      # Slack hung up on us, we'll ask for a new WebSocket URL and reconnect.
      session.error "Websocket Driver received EOF; reconnecting"
      retry
    end



    def channels
      user_id_by_name.keys + group_id_by_name.keys + channel_id_by_name.keys
    end



    def find_channel(id)
      case id
      when /^U/ then find_user(id)
      when /^D/
        user = find_user(get_user_id_for_dm(id))
        Slacks::Channel.new session, {
          "id" => id,
          "is_im" => true,
          "name" => user.username }
      when /^G/
        Slacks::Channel.new session, groups_by_id.fetch(id) do
          raise ArgumentError, "Unable to find a group with the ID #{id.inspect}"
        end
      else
        Slacks::Channel.new session, channels_by_id.fetch(id) do
          raise ArgumentError, "Unable to find a channel with the ID #{id.inspect}"
        end
      end
    end

    def find_user(id)
      Slacks::User.new session, users_by_id.fetch(id) do
        raise ArgumentError, "Unable to find a user with the ID #{id.inspect}"
      end
    end



    def user_exists?(username)
      return false if username.nil?
      to_user_id(username).present?
    rescue ArgumentError
      false
    end

    def users
      fetch_users! if @users_by_id.empty?
      @users_by_id.values
    end



  private
    attr_reader :session,
                :user_ids_dm_ids,
                :users_by_id,
                :user_id_by_name,
                :groups_by_id,
                :group_id_by_name,
                :channels_by_id,
                :channel_id_by_name,
                :websocket_url



    def store_context!(response)
      @websocket_url = response.fetch("url")
      @bot = BotUser.new(response.fetch("self"))
      @team = Team.new(response.fetch("team"))

      @channels_by_id = Hash[response.fetch("channels").map { |attrs| [attrs.fetch("id"), attrs] }]
      @channel_id_by_name = Hash[response.fetch("channels").map { |attrs| ["##{attrs.fetch("name")}", attrs.fetch("id")] }]

      @users_by_id = Hash[response.fetch("users").map { |attrs| [attrs.fetch("id"), attrs] }]
      @user_id_by_name = Hash[response.fetch("users").map { |attrs| ["@#{attrs.fetch("name")}", attrs.fetch("id")] }]

      @groups_by_id = Hash[response.fetch("groups").map { |attrs| [attrs.fetch("id"), attrs] }]
      @group_id_by_name = Hash[response.fetch("groups").map { |attrs| [attrs.fetch("name"), attrs.fetch("id")] }]
    rescue KeyError
      raise ResponseError.new(response, $!.message)
    end



    def to_channel_id(name)
      return name if name =~ /^[DGC]/ # this already looks like a channel id
      return get_dm_for_username(name) if name.start_with?("@")
      return to_group_id(name) unless name.start_with?("#")

      channel_id_by_name[name] || fetch_channels![name] || missing_channel!(name)
    end

    def to_group_id(name)
      group_id_by_name[name] || fetch_groups![name] || missing_group!(name)
    end

    def to_user_id(name)
      user_id_by_name[name] || fetch_users![name] || missing_user!(name)
    end

    def get_dm_for_username(name)
      get_dm_for_user_id to_user_id(name)
    end

    def get_dm_for_user_id(user_id)
      channel_id = user_ids_dm_ids[user_id] ||= begin
        response = api("im.open", user: user_id)
        raise ArgumentError, "Unable to direct message the user #{user_id.inspect}: #{response["error"]}" unless response["ok"]
        response["channel"]["id"]
      end
      raise ArgumentError, "Unable to direct message the user #{user_id.inspect}" unless channel_id
      channel_id
    end



    def fetch_channels!
      response = api("channels.list")
      @channels_by_id = response["channels"].index_by { |attrs| attrs["id"] }
      @channel_id_by_name = Hash[response["channels"].map { |attrs| ["##{attrs["name"]}", attrs["id"]] }]
    end

    def fetch_groups!
      response = api("groups.list")
      @groups_by_id = response["groups"].index_by { |attrs| attrs["id"] }
      @group_id_by_name = Hash[response["groups"].map { |attrs| [attrs["name"], attrs["id"]] }]
    end

    def fetch_users!
      response = api("users.list")
      @users_by_id = response["members"].index_by { |attrs| attrs["id"] }
      @user_id_by_name = Hash[response["members"].map { |attrs| ["@#{attrs["name"]}", attrs["id"]] }]
    end



    def missing_channel!(name)
      raise ArgumentError, "Couldn't find a channel named #{name}"
    end

    def missing_group!(name)
      raise ArgumentError, "Couldn't find a private group named #{name}"
    end

    def missing_user!(name)
      raise ArgumentError, "Couldn't find a user named #{name}"
    end



    def get_user_id_for_dm(dm)
      user_id = user_ids_dm_ids.key(dm)
      unless user_id
        response = api("im.list")
        user_ids_dm_ids.merge! Hash[response["ims"].map { |attrs| attrs.values_at("user", "id") }]
        user_id = user_ids_dm_ids.key(dm)
      end
      raise ArgumentError, "Unable to find a user for the direct message ID #{dm.inspect}" unless user_id
      user_id
    end



    def api(command, options={})
      response = http.post(command, options.merge(token: token))
      MultiJson.load(response.body)

    rescue MultiJson::ParseError
      $!.additional_information[:response_body] = response.body
      $!.additional_information[:response_status] = response.status
      raise
    end

    def http
      @http ||= Faraday.new(url: "https://slack.com/api").tap do |connection|
        connection.use Faraday::RaiseErrors
      end
    end

  end
end