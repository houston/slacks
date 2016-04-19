module Slacks
  class Listener
    attr_reader :matcher, :flags
    attr_accessor :conversation

    def initialize(listeners, matcher, direct, flags, callback)
      # flags.each do |flag|
      #   unless Slacks::Message.can_apply?(flag)
      #     raise ArgumentError, "#{flag.inspect} is not a recognized flag"
      #   end
      # end

      @listeners = listeners
      @matcher = matcher.freeze
      @flags = flags.sort.freeze
      @direct = direct
      @callback = callback
    end

    def match(message)
      matcher.match message.to_s(flags)
    end

    def direct?
      @direct
    end

    def indirect?
      !direct?
    end

    def stop_listening!
      listeners.delete self
      self
    end

    def call(e)
      @callback.call(e)
    end

  private
    attr_reader :listeners
  end
end
