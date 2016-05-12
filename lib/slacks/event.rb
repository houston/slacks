require "slacks/conversation"

module Slacks
  class Event
    attr_reader :message, :channel, :sender

    def initialize(session: nil, message: nil, channel: nil, sender: nil)
      @session = session
      @message = message
      @channel = channel
      @sender = sender
    end

    def user
      return @user if defined?(@user)
      @user = sender && ::User.find_by_slack_username(sender.username)
    end

    def reply(*args)
      channel.reply(*args)
    end

    def random_reply(*args)
      channel.random_reply(*args)
    end

    def typing
      channel.typing
    end

    def start_conversation!
      Conversation.new(session, channel, sender)
    end

  private
    attr_reader :session
  end
end
