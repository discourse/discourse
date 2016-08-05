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
    args[:category] = args[:category].name if args[:category].is_a?(Category)
    TopicCreator.create(user, guardian, args)
  end

  def create_post(args={})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    args[:raw] ||= "This is the raw body of my post, it is cool #{Helpers.next_seq}"
    args[:topic_id] = args[:topic].id if args[:topic]
    user = args.delete(:user) || Fabricate(:user)
    args[:category] = args[:category].name if args[:category].is_a?(Category)
    creator = PostCreator.new(user, args)
    post = creator.create

    if creator.errors.present?
      raise StandardError.new(creator.errors.full_messages.join(" "))
    end

    post
  end

  def generate_username(length=10)
    range = [*'a'..'z']
    Array.new(length){range.sample}.join
  end

  def stub_guardian(user)
    guardian = Guardian.new(user)
    yield(guardian) if block_given?
    Guardian.stubs(new: guardian).with(user)
  end

  def wait_for(&blk)
    i = 0
    result = false
    while !result && i < 300
      result = blk.call
      i += 1
      sleep 0.001
    end

    expect(result).to eq(true)
  end

  def fill_email(mail, from, to, body = nil, subject = nil, cc = nil)
    result = mail.gsub("FROM", from).gsub("TO", to)
    result.gsub!(/Hey.*/m, body)  if body
    result.sub!(/We .*/, subject) if subject
    result.sub!("CC", cc.presence || "")
    result
  end

  def email(email_name)
    fixture_file("emails/#{email_name}.eml")
  end

end
