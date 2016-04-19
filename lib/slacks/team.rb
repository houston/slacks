module Slacks
  class Team
    attr_reader :id, :name, :domain

    def initialize(data)
      @id = data.fetch("id")
      @name = data.fetch("name")
      @domain = data.fetch("domain")
    end

  end
end
