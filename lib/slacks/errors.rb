require "slacks/core_ext/exception"

module Slacks
  class MigrationInProgress < RuntimeError
    def initialize
      super "Team is being migrated between servers. Try the request again in a few seconds."
    end
  end

  class ResponseError < RuntimeError
    attr_reader :response

    def initialize(response, message)
      super message
      @response = response
      additional_information[:response] = response
    end
  end

  class ConnectionError < RuntimeError
    def initialize(event)
      super "There was a connection error in the WebSocket"
      additional_information[:event] = event
    end
  end

  class AlreadyRespondedError < RuntimeError
    def initialize(message=nil)
      super message || "You have already replied to this Slash Command; you can only reply once"
    end
  end

  class NotInChannelError < RuntimeError
    def initialize(channel)
      super "The bot is not in the channel #{channel} and cannot reply"
    end
  end

  class UnableToDirectMessageError < ResponseError
    def initialize(response, user_id)
      super response, "Unable to direct message the user #{user_id.inspect}: #{response["error"]}"
    end
  end
end
