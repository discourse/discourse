module Helpers
  def self.next_seq
    @next_seq = (@next_seq || 0) + 1
  end

  def log_in(fabricator=nil)
    user = Fabricate(fabricator || :user)
    log_in_user(user)
    user
  end

  def log_in_user(user)
    provider = Discourse.current_user_provider.new(request.env)
    provider.log_on_user(user,session,cookies)
  end

  def fixture_file(filename)
    return '' if filename.blank?
    file_path = File.expand_path(Rails.root + 'spec/fixtures/' + filename)
    File.read(file_path)
  end

  def build(*args)
    Fabricate.build(*args)
  end

  def create_topic(args={})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    user = args.delete(:user) || Fabricate(:user)
    guardian = Guardian.new(user)
    TopicCreator.create(user, guardian, args)
  end

  def create_post(args={})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    args[:raw] ||= "This is the raw body of my post, it is cool #{Helpers.next_seq}"
    args[:topic_id] = args[:topic].id if args[:topic]
    user = args.delete(:user) || Fabricate(:user)
    PostCreator.create(user, args)
  end

  def generate_username(length=10)
    range = [*'a'..'z']
    Array.new(length){range.sample}.join
  end
end
