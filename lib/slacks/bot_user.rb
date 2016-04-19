module Slacks
  class BotUser
    attr_reader :id, :name

    def initialize(data)
      @id = data.fetch("id")
      @name = data.fetch("name")
    end

    def to_s
      "@#{name}"
    end

  end
end
