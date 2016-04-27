require "attentive/listener"

module Slacks
  class Listener < Attentive::Listener
    attr_accessor :conversation

    def matches_context?(message)
      contexts = message.contexts.dup
      contexts << :conversation if conversation && conversation.includes?(message)

      return false unless contexts.superset? @required_contexts
      return false unless contexts.disjoint? @prohibited_contexts
      true
    end

  end
end
