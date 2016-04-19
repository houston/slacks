module Slacks
  class Message

    def initialize(session, data)
      @session = session
      @data = data
      @processed_text = Hash.new do |hash, flags|
        hash[flags] = flags.inject(text) { |text, flag| session.apply(flag, text) }.strip
      end
    end


    def channel
      return @channel if defined?(@channel)
      @channel = session.slack.find_channel data["channel"]
    end

    def sender
      return @sender if defined?(@sender)
      @sender = session.slack.find_user data["user"]
    end

    def timestamp
      data["ts"]
    end

    def type
      data.fetch("subtype", "message")
    end

    def text
      return @text if defined?(@text)
      @text = self.class.normalize(data["text"])
    end
    alias :to_str :text

    def to_s(flags=[])
      processed_text[flags]
    end

    def inspect
      "#{text.inspect} (from: #{sender}, channel: #{channel})"
    end

    def add_reaction(emoji)
      session.slack.add_reaction(emoji, self)
    end


    def respond_to_missing?(method, include_all)
      return true if text.respond_to?(method)
      super
    end

    def method_missing(method, *args, &block)
      return text.public_send(method, *args, &block) if text.respond_to?(method)
      super
    end


    def self.normalize(text)
      text
        .gsub(/[“”]/, "\"")
        .gsub(/[‘’]/, "'")
        .strip
    end

  private
    attr_reader :session, :data, :processed_text
  end
end
