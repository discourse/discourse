# frozen_string_literal: true

# can be used to generate a mock db for profiling purposes

# we want our script to generate a consistent output, to do so
#  we monkey patch array sample so it always uses the same rng
class Array
  RNG = Random.new(1_098_109_928_029_800)

  def sample
    self[RNG.rand(size)]
  end
end

# based on https://gist.github.com/zaius/2643079
def unbundled_require(gem)
  if defined?(::Bundler)
    spec_path = Dir.glob("#{Gem.dir}/specifications/#{gem}-*.gemspec").last
    raise LoadError if spec_path.nil?

    spec = Gem::Specification.load spec_path
    spec.activate
  end

  begin
    require gem
  end
end

def sentence
  @gabbler ||=
    Gabbler.new.tap do |gabbler|
      story = File.read(File.dirname(__FILE__) + "/alice.txt")
      gabbler.learn(story)
    end

  sentence = +""
  until sentence.length > 800
    sentence << @gabbler.sentence
    sentence << "\n"
  end
  sentence
end

def create_user(seq, admin: false, username: nil)
  User.new.tap do |user|
    user.email = "user@localhost#{seq}.fake"
    user.username = username || "user#{seq}"
    user.password = "password12345abc"
    user.save!

    if admin
      user.grant_admin!
      user.change_trust_level!(TrustLevel[4])
    end

    user.activate
  end
end

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

Jobs.run_immediately!

unless Rails.env == "profile"
  puts "This script should only be used in the profile environment"
  exit
end

# by default, Discourse has a "system" and `discobot` account
if User.count > 2
  puts "Only run this script against an empty DB"
  exit
end

require "optparse"
begin
  unbundled_require "gabbler"
rescue LoadError
  puts "installing gabbler gem"
  puts `gem install gabbler`
  unbundled_require "gabbler"
end

number_of_users = 100
puts "Creating #{number_of_users} users"
number_of_users.times.map do |i|
  putc "."
  create_user(i)
end

puts
puts "Creating 1 admin user"
admin_user = create_user(number_of_users + 1, admin: true, username: "admin1")

users = User.human_users.all

puts
puts "Creating 10 categories"
categories =
  10.times.map do |i|
    putc "."
    Category.create(name: "category#{i}", text_color: "ffffff", color: "000000", user: admin_user)
  end

puts
puts "Creating 100 topics"
topic_ids =
  100.times.map do
    post =
      PostCreator.create(
        admin_user,
        raw: sentence,
        title: sentence[0..50].strip,
        category: categories.sample.id,
        skip_validations: true,
      )
    putc "."
    post.topic_id
  end

puts
puts "Creating 2000 replies"
2000.times do
  putc "."
  PostCreator.create(
    users.sample,
    raw: sentence,
    topic_id: topic_ids.sample,
    skip_validations: true,
  )
end

puts
puts "creating perf test topic"
first_post =
  PostCreator.create(
    users.sample,
    raw: sentence,
    title: "I am a topic used for perf tests",
    category: categories.sample.id,
    skip_validations: true,
  )

puts
puts "Creating 100 replies for perf test topic"
100.times do
  putc "."
  PostCreator.create(
    users.sample,
    raw: sentence,
    topic_id: first_post.topic_id,
    skip_validations: true,
  )
end

# no sidekiq so update some stuff
Category.update_stats
Jobs::PeriodicalUpdates.new.execute(nil)
