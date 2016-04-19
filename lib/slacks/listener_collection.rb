require "thread_safe"

module Slacks
  class ListenerCollection

    def initialize
      @listeners = ThreadSafe::Array.new
    end

    def listen_for(matcher, flags=[], &block)
      Listener.new(self, matcher, true, flags, block).tap do |listener|
        @listeners.push listener
      end
    end

    def overhear(matcher, flags=[], &block)
      Listener.new(self, matcher, false, flags, block).tap do |listener|
        @listeners.push listener
      end
    end

    def each(&block)
      @listeners.each(&block)
    end

    def delete(listener)
      @listeners.delete listener
    end

  end
end
