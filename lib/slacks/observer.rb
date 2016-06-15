require "concurrent/array"
require "concurrent/hash"

module Slacks
  module Observer

    def on(event, &block)
      observers_of(event).push(block)
    end

  protected

    def trigger(event, *args)
      raise ArgumentError, "Must specify an event to trigger" unless event
      observers_of(event).each do |block|
        block.call(*args)
      end
    end

    def observers_of(event)
      observers[event.to_sym]
    end

    def observers
      return @observers if defined?(@observers)
      @observers = Concurrent::Hash.new { |hash, key| hash[key] = Concurrent::Array.new }
    end

  end
end
