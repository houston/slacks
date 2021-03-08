# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "slacks/version"

Gem::Specification.new do |spec|
  spec.name          = "slacks"
  spec.version       = Slacks::VERSION
  spec.authors       = ["Bob Lail"]
  spec.email         = ["bob.lailfamily@gmail.com"]

  spec.summary       = %q{A library for communicating via Slack}
  spec.homepage      = "https://github.com/houston/slacks"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # https://blog.jcoglan.com/2013/05/06/websocket-driver-an-io-agnostic-websocket-module-or-why-most-protocol-libraries-arent/
  spec.add_dependency "websocket-driver"
  spec.add_dependency "multi_json"
  spec.add_dependency "faraday"
  spec.add_dependency "concurrent-ruby"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "minitest-reporters-turn_reporter"
end
