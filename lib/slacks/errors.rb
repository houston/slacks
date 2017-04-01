require "slacks/core_ext/exception"

module Slacks
  module Response
    class Error < RuntimeError
      attr_reader :command, :params, :response

      def initialize(command, params, response, message)
        super message
        @command = command
        @params = params
        @response = response
        additional_information[:command] = command
        additional_information[:params] = params
        additional_information[:response] = response
      end
    end

    class UnspecifiedError < ::Slacks::Response::Error
      def initialize(command, params, response)
        super command, params, response, "Request failed with #{response["error"].inspect}"
      end
    end

    @_errors = {}

    def self.fetch(error_code)
      @_errors.fetch(error_code, ::Slacks::Response::UnspecifiedError)
    end

    {
      "account_inactive"       => "Authentication token is for a deleted user or team.",
      "already_reacted"        => "The specified item already has the user/reaction combination.",
      "bad_timestamp"          => "Value passed for timestamp was invalid.",
      "cant_update_message"    => "Authenticated user does not have permission to update this message.",
      "channel_not_found"      => "Value passed for channel was invalid.",
      "edit_window_closed"     => "The message cannot be edited due to the team message edit settings",
      "fatal_error"            => "",
      "file_comment_not_found" => "File comment specified by file_comment does not exist.",
      "file_not_found"         => "File specified by file does not exist.",
      "invalid_arg_name"       => "The method was passed an argument whose name falls outside the bounds of common decency. This includes very long names and names with non-alphanumeric characters other than _. If you get this error, it is typically an indication that you have made a very malformed API call.",
      "invalid_array_arg"      => "The method was passed a PHP-style array argument (e.g. with a name like foo[7]). These are never valid with the Slack API.",
      "invalid_auth"           => "Invalid authentication token.",
      "invalid_charset"        => "The method was called via a POST request, but the charset specified in the Content-Type header was invalid. Valid charset names are: utf-8 iso-8859-1.",
      "invalid_form_data"      => "The method was called via a POST request with Content-Type application/x-www-form-urlencoded or multipart/form-data, but the form data was either missing or syntactically invalid.",
      "invalid_name"           => "Value passed for name was invalid.",
      "invalid_post_type"      => "The method was called via a POST request, but the specified Content-Type was invalid. Valid types are: application/json application/x-www-form-urlencoded multipart/form-data text/plain.",
      "is_archived"            => "Channel has been archived.",
      "message_not_found"      => "Message specified by channel and timestamp does not exist.",
      "migration_in_progress"  => "Team is being migrated between servers. See the team_migration_started event documentation for details.",
      "missing_post_type"      => "The method was called via a POST request and included a data payload, but the request did not include a Content-Type header.",
      "msg_too_long"           => "Message text is too long",
      "no_item_specified"      => "file, file_comment, or combination of channel and timestamp was not specified.",
      "no_text"                => "No message text provided",
      "not_authed"             => "No authentication token provided.",
      "not_in_channel"         => "Cannot post user messages to a channel they are not in.",
      "rate_limited"           => "Application has posted too many messages, read the Rate Limit documentation for more information",
      "request_timeout"        => "The method was called via a POST request, but the POST data was either missing or truncated.",
      "too_many_attachments"   => "Too many attachments were provided with this message. A maximum of 100 attachments are allowed on a message.",
      "too_many_emoji"         => "The limit for distinct reactions (i.e emoji) on the item has been reached.",
      "too_many_reactions"     => "The limit for reactions a person may add to the item has been reached."
    }.each do |error_code, message|
      class_name = error_code.classify
      class_name = {
        "MsgTooLong" => "MessageTooLong"
      }.fetch(class_name, class_name)

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        class #{class_name} < ::Slacks::Response::Error
          def initialize(command, params, response)
            super command, params, response, "#{message}"
          end
        end

        @_errors["#{error_code}"] = ::Slacks::Response::#{class_name}
      RUBY
    end
  end

  class ConnectionError < RuntimeError
    def initialize(event)
      super "There was a connection error in the WebSocket"
      additional_information[:event] = event
    end
  end

  class NotInChannelError < RuntimeError
    def initialize(channel)
      super "The bot is not in the channel #{channel} and cannot reply"
    end
  end

  class MissingTokenError < ArgumentError
    def initialize
      super "Unable to connect to Slack; a token has no"
    end
  end

  class NotListeningError < ArgumentError
    def initialize
      super "Not connected to the RTM API; call `listen!` first"
    end
  end
end
