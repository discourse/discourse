# frozen_string_literal: true

module Helpers
  extend ActiveSupport::Concern

  def self.next_seq
    @next_seq = (@next_seq || 0) + 1
  end

  def log_in(fabricator = nil)
    user = Fabricate(fabricator || :user)
    log_in_user(user)
    user
  end

  def log_in_user(user)
    provider = Discourse.current_user_provider.new(request.env)
    provider.log_on_user(user, session, cookies)
    provider
  end

  def log_out_user(provider)
    provider.log_off_user(session, cookies)
  end

  def fixture_file(filename)
    return '' if filename.blank?
    file_path = File.expand_path(Rails.root + 'spec/fixtures/' + filename)
    File.read(file_path)
  end

  def build(*args)
    Fabricate.build(*args)
  end

  def create_topic(args = {})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    user = args.delete(:user) || Fabricate(:user)
    guardian = Guardian.new(user)
    args[:category] = args[:category].id if args[:category].is_a?(Category)
    TopicCreator.create(user, guardian, args)
  end

  def create_post(args = {})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    args[:raw] ||= "This is the raw body of my post, it is cool #{Helpers.next_seq}"
    args[:topic_id] = args[:topic].id if args[:topic]
    user = args.delete(:user) || Fabricate(:user)
    args[:category] = args[:category].id if args[:category].is_a?(Category)
    creator = PostCreator.new(user, args)
    post = creator.create

    if creator.errors.present?
      raise StandardError.new(creator.errors.full_messages.join(" "))
    end

    post
  end

  def generate_username(length = 10)
    range = [*'a'..'z']
    Array.new(length) { range.sample }.join
  end

  def stub_guardian(user)
    guardian = Guardian.new(user)
    yield(guardian) if block_given?
    Guardian.stubs(new: guardian).with(user, anything)
  end

  def wait_for(on_fail: nil, &blk)
    i = 0
    result = false
    while !result && i < 1000
      result = blk.call
      i += 1
      sleep 0.001
    end

    on_fail&.call
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

  def create_staff_tags(tag_names)
    tag_group = Fabricate(:tag_group, name: 'Staff Tags')
    TagGroupPermission.create!(
      tag_group: tag_group,
      group_id: Group::AUTO_GROUPS[:everyone],
      permission_type: TagGroupPermission.permission_types[:readonly]
    )
    TagGroupPermission.create!(
      tag_group: tag_group,
      group_id: Group::AUTO_GROUPS[:staff],
      permission_type: TagGroupPermission.permission_types[:full]
    )
    tag_names.each do |name|
      tag_group.tags << (Tag.where(name: name).first || Fabricate(:tag, name: name))
    end
  end

  def create_hidden_tags(tag_names)
    tag_group = Fabricate(:tag_group,
      name: 'Hidden Tags',
      permissions: { staff: :full }
    )
    tag_names.each do |name|
      tag_group.tags << (Tag.where(name: name).first || Fabricate(:tag, name: name))
    end
  end

  def sorted_tag_names(tag_records)
    tag_records.map { |t| t.is_a?(String) ? t : t.name }.sort
  end

  def expect_same_tag_names(a, b)
    expect(sorted_tag_names(a)).to eq(sorted_tag_names(b))
  end

  def capture_stdout
    old_stdout = $stdout
    io = StringIO.new
    $stdout = io
    yield
    io.string
  ensure
    $stdout = old_stdout
  end

  def set_subfolder(f)
    global_setting :relative_url_root, f
    old_root = ActionController::Base.config.relative_url_root
    ActionController::Base.config.relative_url_root = f

    before_next_spec do
      ActionController::Base.config.relative_url_root = old_root
    end
  end

  class StubbedJob
    def initialize; end
    def perform(args); end
  end
end
