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
      messages.flatten!
      return unless messages.any?

      first_message = messages.shift
      message_options = {}
      message_options = messages.shift if messages.length == 1 && messages[0].is_a?(Hash)
      slack.send_message(first_message, message_options.merge(channel: id))

      messages.each do |message|
        sleep message.length / slack.typing_speed
        slack.send_message(message, channel: id)
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

    def to_s
      return name if private?
      return "@#{name}" if direct_message?
      "##{name}"
    end

  private
    attr_reader :slack
  end
end
