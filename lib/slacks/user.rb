module Slacks
  class User
    attr_reader :id, :username, :email, :first_name, :last_name

    def initialize(session, attributes={})
      @session = session

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

  end
end
