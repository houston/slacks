require "attentive/listener_collection"
require "slacks/listener"

module Slacks
  class ListenerCollection < Attentive::ListenerCollection

    def overhear(*args, &block)
      options = args.last.is_a?(::Hash) ? args.pop : {}
      options[:context] = { in: :any }
      listen_for(*args, options, &block)
    end

    def listen_for(*args, &block)
      options = args.last.is_a?(::Hash) ? args.pop : {}

      Slacks::Listener.new(self, args, options, block).tap do |listener|
        push listener
      end
    end

  end
end
