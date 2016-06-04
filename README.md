# Slacks

A library for communicating via Slack



## Usage

##### Speaking

Slacks uses [Slack's Web API](https://api.slack.com/web) to allow your bot to communicate on Slack:

```ruby
require "slacks"
slack = Slacks::Connection.new("xoxb-0123456789-abcdefghijklmnopqrstuvwx")
slack.send_message "Hi everyone!", channel: "#general"
```

You can post [attachment](https://api.slack.com/docs/attachments):

```ruby
slack.send_message "", channel: "#general", attachments: [{
  color: "#36a64f",
  fallback: "Tests passed!",
  text: "Tests passed!",
  fields: [{
    title: "Tests",
    value: "143",
    short: true
  }, {
    title: "Assertions",
    value: "298",
    short: true
  }]
}]
```

(For more information about sending messages, see [chat.postMessage](https://api.slack.com/methods/chat.postMessage).)

You can indicate that your bot is typing:

```ruby
slack.typing_on "#general"
```

You can react to messages:

```ruby
slack.add_reaction "+1", message.ts
```



#### Listening

Slacks uses [Slack's RTM API](https://api.slack.com/rtm) to allow your bot to listen on Slack. Slacks connects to a websocket provided by Slack and allows you to set up listeners for events by type:

```ruby
require "slacks"
slack = Slacks::Connection.new("xoxb-0123456789-abcdefghijklmnopqrstuvwx")
slack.on "message" do |event|
  puts "I heard #{event["user"]} say #{event["text"].inspect}"
end
slack.on "reaction_added" do |event|
  next unless event["item"]["type"] == "message"
  message = slack.get_message data["item"]["channel"], data["item"]["ts"]
  puts "#{event["user"]} added #{event["reaction"]} to #{message["text"].inspect}"
end
slack.listen!
```



## Installation

Add this line to your application's Gemfile:

```ruby
gem "slacks"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install slacks




## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/slacks.



## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
