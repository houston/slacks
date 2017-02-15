module Slacks
  class Channel
    attr_reader :id, :name, :type

    def initialize(slack, attributes={})
      @slack = slack
      @id = attributes["id"]
      @name = attributes["name"]
      @type = :channel
      @type = :group if attributes["is_group"]
      @type = :direct_message if attributes["is_im"]
    end

    def reply(*messages)
      return unless messages.any?

      if messages.first.is_a?(Array)
        reply_many(messages[0])
      else
        reply_one(*messages)
      end
    end
    alias :say :reply

    def typing
      slack.typing_on(self)
    end

    def direct_message?
      type == :direct_message
    end
    alias :dm? :direct_message?
    alias :im? :direct_message?

    def private_group?
      type == :group
    end
    alias :group? :private_group?
    alias :private? :private_group?

    def guest?
      false
    end

    def inspect
      "<Slacks::Channel id=\"#{id}\" name=\"#{name}\">"
    end

    def ==(other)
      self.class == other.class && self.id == other.id
    end

    def to_s
      return name if private?
      return "@#{name}" if direct_message?
      "##{name}"
    end

  protected

    def reply_one(message, options={})
      slack.send_message(message, options.merge(channel: id))
    end

    def reply_many(messages)
      messages.each_with_index.map do |message, i|
        sleep message.length / slack.typing_speed if i > 0
        slack.send_message(message, channel: id)
      end
    end

  private
    attr_reader :slack
  end
end
