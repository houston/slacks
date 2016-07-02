module Slacks
  class User
    attr_reader :id, :username, :email, :first_name, :last_name

    def initialize(slack, attributes={})
      @slack = slack

      profile = attributes["profile"]
      @id = attributes["id"]
      @username = attributes["name"]
      @email = profile["email"]
      @first_name = profile["first_name"]
      @last_name = profile["last_name"]
    end

    def name
      "#{first_name} #{last_name}"
    end

    def inspect
      "<Slacks::User id=\"#{id}\" name=\"#{name}\">"
    end

    def to_s
      "@#{username}"
    end

    def ==(other)
      self.class == other.class && self.id == other.id
    end

  private
    attr_reader :slack
  end
end
