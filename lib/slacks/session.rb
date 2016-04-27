require "slacks/connection"
require "slacks/listener_collection"

module Slacks
  class Session
    attr_reader :listeners, :slack

    def initialize(token, &block)
      @slack = Slacks::Connection.new(token)
      @listeners = Slacks::ListenerCollection.new

      if block_given?
        listeners.instance_eval(&block)
        start!
      end
    end

    def listen_for(matcher, flags=[], &block)
      listeners.listen_for(matcher, flags, &block)
    end

    def overhear(matcher, flags=[], &block)
      listeners.overhear(matcher, flags, &block)
    end


    def start!
      slack.listen!(self)
    end

    def connected
    end

    def error(message)
      # TODO
      puts "\e[33m[slack:error] #{message}\e[0m"
    end

    def apply(flag, text)
      send :"_apply_#{flag}", text
    end

    def can_apply?(flag)
      respond_to? :"_apply_#{flag}", true
    end

    def message(data)

      # Don't respond to things that another bot said
      return if data.fetch("subtype", "message") == "bot_message"

      # Normalize mentions of users
      data["text"].gsub!(/<@U[^|]+\|([^>]*)>/, "@\\1")

      # Normalize mentions of channels
      data["text"].gsub!(/<[@#]?([UC][^>]+)>/) do |match|
        begin
          slack.find_channel($1)
        rescue ArgumentError
          match
        end
      end

      message = Slacks::Message.new(self, data)

      # Is someone talking directly to the bot?
      direct_mention = message.channel.direct_message? || message[slack.bot.name]

      listeners.each do |listener|
        # Listeners come in two flavors: direct and indirect
        #
        # To trigger a direct listener, the but must be directly
        # spoken to: as when the bot is mentioned or it is in
        # a conversation with someone.
        #
        # An indirect listener is triggered in any context
        # when it matches.
        #
        # We can ignore any listener that definitely doesn't
        # meet these criteria.
        next unless listener.indirect? or direct_mention or listener.conversation

        message = Slacks::Message.new(self, data)

        # Does the message match one of our listeners?
        match_data = listener.match message
        next unless match_data

        # TODO: Want event.message to be the processed text
        event = Slacks::RtmEvent.new(
          session: self,
          message: message,
          match_data: match_data,
          listener: listener)

        # Skip listeners if they are not part of this conversation
        next unless listener.indirect? or direct_mention or listener.conversation.includes?(event)

        invoke! listener, event
      end
    # rescue Exception
    #   # TODO
    #   # Houston.report_exception $!
    #   puts "\e[31m[slack:exception] (#{$!.class}) #{$!.message}\n  #{$!.backtrace.join("\n  ")}\e[0m"
    end

    def invoke!(listener, event)
      # # TODO
      # puts "\e[35m[slack:hear:#{event.message_object.type}] #{event.message_object.inspect}\e[0m"

      listener.call(event)
      # Thread.new do
      #   begin
      #     @callback.call(e)
      #   rescue Exception # rescues StandardError by default; but we want to rescue and report all errors
      #     # TODO
      #     # Houston.report_exception $!, parameters: {channel: e.channel, message: e.message, sender: e.sender}
      #     puts "\e[31m[slack:exception] (#{$!.class}) #{$!.message}\n  #{$!.backtrace.join("\n  ")}\e[0m"
      #     e.reply "An error occurred when I was trying to answer you"
      #   ensure
      #     ActiveRecord::Base.clear_active_connections! if defined?(ActiveRecord)
      #   end
      # end
    end

    def _apply_downcase(text)
      text.downcase
    end

    def _apply_no_punctuation(text)
      # Need to leave @ and # in @mentions and #channels
      text.gsub(/[^\w\s@#]/, "")
    end

    def _apply_no_mentions(text)
      text.gsub(/(?:^|\W+)#{slack.bot}\b/, "")
    end

    def _apply_no_emoji(text)
      text.gsub(/(?::[^:]+:)/, "")
    end

  end
end
