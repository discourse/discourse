# frozen_string_literal: true

# used during local testing, simulates a user active on the site.
#
# by default 1 new topic every 30 sec, 1 reply to last topic every 30 secs

require 'optparse'
require 'gabbler'

user_id = nil

def sentence
  @gabbler ||= Gabbler.new.tap do |gabbler|
    story = File.read(File.dirname(__FILE__) + "/alice.txt")
    gabbler.learn(story)
  end

  sentence = +""
  until sentence.length > 800 do
    sentence << @gabbler.sentence
    sentence << "\n"
  end
  sentence
end

OptionParser.new do |opts|
  opts.banner = "Usage: ruby user_simulator.rb [options]"
  opts.on("-u", "--user NUMBER", "user id") do |u|
    user_id = u.to_i
  end
end.parse!

unless user_id
  puts "user must be specified"
  exit
end

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

unless ["profile", "development"].include? Rails.env
  puts "Bad idea to run a script that inserts random posts in any non development environment"
  exit
end

user = User.find(user_id)
last_topics = Topic.order('id desc').limit(10).pluck(:id)

puts "Simulating activity for user id #{user.id}: #{user.name}"

while true
  puts "Creating a random topic"
  category = Category.where(read_restricted: false).order('random()').first
  PostCreator.create(user, raw: sentence, title: sentence[0..50].strip, category: category.id)

  puts "creating random reply"
  PostCreator.create(user, raw: sentence, topic_id: last_topics.sample)

  sleep 2
end
