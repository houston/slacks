$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "slacks"

require "minitest/reporters/turn_reporter"
MiniTest::Reporters.use! Minitest::Reporters::TurnReporter.new

require "minitest/autorun"
