# frozen_string_literal: true

GIT_INITIAL_BRANCH_SUPPORTED = Gem::Version.new(`git --version`.match(/[\d\.]+/)[0]) >= Gem::Version.new("2.28.0")

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
    cookie_jar = ActionDispatch::Request.new(request.env).cookie_jar
    provider = Discourse.current_user_provider.new(request.env)
    provider.log_on_user(user, session, cookie_jar)
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

  def email(email_name)
    fixture_file("emails/#{email_name}.eml")
  end

  def create_staff_only_tags(tag_names)
    create_limited_tags('Staff Tags', Group::AUTO_GROUPS[:staff], tag_names)
  end

  def create_limited_tags(tag_group_name, group_id, tag_names)
    tag_group = Fabricate(:tag_group, name: tag_group_name)
    TagGroupPermission.where(
      tag_group: tag_group,
      group_id: Group::AUTO_GROUPS[:everyone],
      permission_type: TagGroupPermission.permission_types[:full]
    ).update(permission_type: TagGroupPermission.permission_types[:readonly])
    TagGroupPermission.create!(
      tag_group: tag_group,
      group_id: group_id,
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

  def capture_output(output_name)
    if ENV['RAILS_ENABLE_TEST_STDOUT']
      yield
      return
    end

    previous_output = output_name == :stdout ? $stdout : $stderr

    io = StringIO.new
    output_name == :stdout ? $stdout = io : $stderr = io

    yield
    io.string
  ensure
    output_name == :stdout ? $stdout = previous_output : $stderr = previous_output
  end

  def capture_stdout(&block)
    capture_output(:stdout, &block)
  end

  def capture_stderr(&block)
    capture_output(:stderr, &block)
  end

  def set_subfolder(f)
    global_setting :relative_url_root, f
    old_root = ActionController::Base.config.relative_url_root
    ActionController::Base.config.relative_url_root = f

    before_next_spec do
      ActionController::Base.config.relative_url_root = old_root
    end
  end

  def setup_git_repo(files)
    repo_dir = Dir.mktmpdir
    `cd #{repo_dir} && git init . #{"--initial-branch=main" if GIT_INITIAL_BRANCH_SUPPORTED}`
    `cd #{repo_dir} && git config user.email 'someone@cool.com'`
    `cd #{repo_dir} && git config user.name 'The Cool One'`
    `cd #{repo_dir} && git config commit.gpgsign 'false'`
    files.each do |name, data|
      FileUtils.mkdir_p(Pathname.new("#{repo_dir}/#{name}").dirname)
      File.write("#{repo_dir}/#{name}", data)
      `cd #{repo_dir} && git add #{name}`
    end
    `cd #{repo_dir} && git commit -am 'first commit'`
    repo_dir
  end

  def stub_const(target, const, value)
    old = target.const_get(const)
    target.send(:remove_const, const)
    target.const_set(const, value)
    yield
  ensure
    target.send(:remove_const, const)
    target.const_set(const, old)
  end
end
