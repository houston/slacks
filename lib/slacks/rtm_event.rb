require "slacks/event"

module Slacks
  class RtmEvent < Event
    attr_reader :match, :message_object

    def initialize(session: nil, message: nil, match_data: nil, listener: nil)
      super(session: session, message: message.text, channel: message.channel, sender: message.sender)
      @message_object = message
      @match = match_data
      @listener = listener
    end

    def matched?(key)
      match[key].present?
    end

    def stop_listening!
      listener.stop_listening!
    end

    def react(emoji)
      message_object.add_reaction(emoji)
    end

  private
    attr_reader :listener

  end
end
