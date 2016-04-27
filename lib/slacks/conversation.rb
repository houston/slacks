require "thread_safe"

module Slacks
  class Conversation

    def initialize(session, channel, sender)
      @session = session
      raise NotInChannelError, channel if channel.guest?

      @channel = channel
      @sender = sender
      @listeners = ThreadSafe::Array.new
    end

    def listen_for(*args, &block)
      session.listen_for(*args, &block).tap do |listener|
        listener.conversation = self
        listeners.push listener
      end
    end

    def includes?(e)
      e.channel.id == channel.id && e.sender.id == sender.id
    end

    def reply(*messages)
      channel.reply(*messages)
    end
    alias :say :reply

    def ask(question, expect: nil)
      listen_for(*Array(expect)) do |e|
        e.stop_listening!
        yield e
      end

      reply question
    end

    def end!
      listeners.each(&:stop_listening!)
    end

  private
    attr_reader :session, :channel, :sender, :listeners

  end
end
