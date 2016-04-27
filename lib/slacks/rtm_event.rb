require "slacks/event"

module Slacks
  class RtmEvent < Event
    attr_reader :match

    def initialize(session, match)
      @match = match
      @listener = match.listener
      message = match.message
      super(session: session, message: message, channel: message.channel, sender: message.sender)
    end

    def matched?(key)
      match.matched?(key)
    end

    def stop_listening!
      listener.stop_listening!
    end

    def react(emoji)
      message.add_reaction(emoji)
    end

  private
    attr_reader :listener

  end
end
