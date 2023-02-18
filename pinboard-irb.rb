#!/usr/bin/env irb --noverbose --noecho --simple-prompt
# encoding: utf-8

# Adapted from https://github.com/badboy/pinboard-cli

require 'cgi'
require 'uri'

module URI
  def self.encode(*args)
    CGI.escape(args[0])
  end
end

require 'pinboard'

module Pinboard
  class Client
    def recent_unread
      recent(toread: :yes)
    end
  end
end

TOKEN_FILE = File.expand_path("~/.pinboard-token") ; nil
token = IO.read(TOKEN_FILE).chomp

class RateLimitedPinboardClientWrapper
  attr_accessor :actual_pin

  def initialize(pin)
    @last_called = {}
    @cached_results = {}
    @actual_pin = pin
  end

  def method_interval_allowed_now?(m)
    if @last_called[m]
      (Time.now - @last_called[m]).to_i > method_interval_allowed_secs(m)
    else
      true
    end
  end

  def method_interval_allowed_secs(m)
    # https://pinboard.in/api/
    case m
    when :recent_unread, :recent
      60
    when :posts
      5 * 60
    else
      3
    end
  end

  def method_missing(m, *args, &block)
    if @actual_pin.respond_to?(m)
      if method_interval_allowed_now?(m)
        @last_called[m] = Time.now
        @cached_results[m] = @actual_pin.send(m, *args, &block)
      else
        puts "*** Rate limited for #{m} [#{@last_called}] ***"
        puts "*** Returning cached results ***"
      end
      return @cached_results[m]
    end
    raise "Unknown @actual_pin.#{m}"
  end
end

@pin = RateLimitedPinboardClientWrapper.new(Pinboard::Client.new(token: token))

@spin2win_recent_unreads = []
def spin2win
  @spin2win_recent_unreads = @pin.recent_unread.dup if @spin2win_recent_unreads.empty?
  @spin2win_recent_unreads = @spin2win_recent_unreads.shuffle
  post = @spin2win_recent_unreads.pop
  puts post.href
  p @pin.delete(post.href)
  system "open #{post.href}"
end

if ARGV.first == "spin2win"
  spin2win
  exit
end

puts "
  Try @pin, @pin.recent_unread, @pin.dates
  Or try: spin2win
"

irb