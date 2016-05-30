require "slacks/connection"
require "slacks/listener_collection"
require "slacks/message"
require "attentive"

module Slacks
  class Session
    include Attentive

    attr_reader :slack

    def initialize(token, &block)
      @slack = Slacks::Connection.new(token)

      if block_given?
        listeners.instance_eval(&block)
        start!
      end
    end

    def listeners
      @listeners ||= Slacks::ListenerCollection.new
    end



    def start!
      slack.listen!(self)
    end

    def connected
      Attentive.invocations = [slack.bot.name, slack.bot.to_s]
    end

    def error(error_message)
    end

    def message(data)

      # Don't respond to things that another bot said
      return if data.fetch("subtype", "message") == "bot_message"

      # Normalize mentions of users
      data["text"].gsub!(/<@U[^|]+\|([^>]*)>/, %q{@\1})

      # Normalize mentions of channels
      data["text"].gsub!(/<[@#]?([UC][^>]+)>/) do |match|
        begin
          slack.find_channel($1)
        rescue ArgumentError
          match
        end
      end

      message = Slacks::Message.new(self, data)
      hear(message).each do |match|

        event = Slacks::RtmEvent.new(self, match)
        invoke! match.listener, event

        # Invoke only one listener per message
        return
      end
    end

    def reaction_added(data)
    end

    def reaction_removed(data)
    end

  protected

    def invoke!(listener, event)
      listener.call(event)
    end

  end
end
