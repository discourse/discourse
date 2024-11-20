# frozen_string_literal: true

GIT_INITIAL_BRANCH_SUPPORTED =
  Gem::Version.new(`git --version`.match(/[\d\.]+/)[0]) >= Gem::Version.new("2.28.0")

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
    return "" if filename.blank?
    file_path = File.expand_path(Rails.root + "spec/fixtures/" + filename)
    File.read(file_path)
  end

  def build(*args)
    Fabricate.build(*args)
  end

  def create_topic(args = {})
    args[:title] ||= "This is my title #{Helpers.next_seq}"
    user = args.delete(:user)
    user = Fabricate(:user, refresh_auto_groups: true) if !user
    guardian = Guardian.new(user)
    args[:category] = args[:category].id if args[:category].is_a?(Category)
    TopicCreator.create(user, guardian, args)
  end

  def create_post(args = {})
    # Pretty much all the tests with `create_post` will fail without this
    # since allow_uncategorized_topics is now false by default
    SiteSetting.allow_uncategorized_topics = true unless args[:allow_uncategorized_topics] == false

    args[:title] ||= "This is my title #{Helpers.next_seq}"
    args[:raw] ||= "This is the raw body of my post, it is cool #{Helpers.next_seq}"
    args[:topic_id] = args[:topic].id if args[:topic]
    user = args.delete(:user) || Fabricate(:user, refresh_auto_groups: true)
    args[:category] = args[:category].id if args[:category].is_a?(Category)
    creator = PostCreator.new(user, args)
    post = creator.create

    raise StandardError.new(creator.errors.full_messages.join(" ")) if creator.errors.present?

    post
  end

  def stub_guardian(user)
    guardian = Guardian.new(user)
    yield(guardian) if block_given?
    Guardian.stubs(new: guardian).with(user, anything)
  end

  def wait_for(on_fail: nil, timeout: 1, &blk)
    i = 0
    result = false
    while !result && i < timeout * 1000
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
    create_limited_tags("Staff Tags", Group::AUTO_GROUPS[:staff], tag_names)
  end

  def create_limited_tags(tag_group_name, group_id, tag_names)
    tag_group = Fabricate(:tag_group, name: tag_group_name)
    TagGroupPermission.where(
      tag_group: tag_group,
      group_id: Group::AUTO_GROUPS[:everyone],
      permission_type: TagGroupPermission.permission_types[:full],
    ).update(permission_type: TagGroupPermission.permission_types[:readonly])
    TagGroupPermission.create!(
      tag_group: tag_group,
      group_id: group_id,
      permission_type: TagGroupPermission.permission_types[:full],
    )
    tag_names.each do |name|
      tag_group.tags << (Tag.where(name: name).first || Fabricate(:tag, name: name))
    end
  end

  def create_hidden_tags(tag_names)
    tag_group = Fabricate(:tag_group, name: "Hidden Tags", permissions: { staff: :full })
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
    if ENV["RAILS_ENABLE_TEST_STDOUT"]
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

  def set_subfolder(new_root)
    global_setting :relative_url_root, new_root

    old_root = ActionController::Base.config.relative_url_root
    ActionController::Base.config.relative_url_root = new_root
    Rails.application.routes.stubs(:relative_url_root).returns(new_root)

    before_next_spec { ActionController::Base.config.relative_url_root = old_root }

    if RSpec.current_example.metadata[:type] == :system
      Capybara.app.map("/") { run lambda { |env| [404, {}, [""]] } }
      Capybara.app.map(new_root) { run Rails.application }

      before_next_spec do
        Capybara.app.map(new_root) { run lambda { |env| [404, {}, [""]] } }
        Capybara.app.map("/") { run Rails.application }
      end
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

  def add_to_git_repo(repo_dir, files)
    files.each do |name, data|
      FileUtils.mkdir_p(Pathname.new("#{repo_dir}/#{name}").dirname)
      File.write("#{repo_dir}/#{name}", data)
      `cd #{repo_dir} && git add #{name}`
    end
    `cd #{repo_dir} && git commit -am 'add #{files.size} files'`
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

  def track_sql_queries
    queries = []
    callback = ->(*, payload) do
      queries << payload.fetch(:sql) if %w[CACHE SCHEMA].exclude?(payload.fetch(:name))
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      ActiveSupport::Notifications.subscribed(callback, "sql.mini_sql") { yield }
    end

    queries
  end

  def stub_ip_lookup(stub_addr, ips)
    Addrinfo
      .stubs(:getaddrinfo)
      .with { |addr, _| addr == stub_addr }
      .returns(
        ips.map { |ip| Addrinfo.new([IPAddr.new(ip).ipv6? ? "AF_INET6" : "AF_INET", 80, nil, ip]) },
      )
  end

  def with_search_indexer_enabled
    SearchIndexer.enable
    yield
  ensure
    SearchIndexer.disable
  end

  # Uploads a theme from a directory.
  #
  # @param set_theme_as_default [Boolean] Whether to set the uploaded theme as the default theme for the site. Defaults to true.
  #
  # @return [Theme] The uploaded theme model given by `models/theme.rb`.
  #
  # @example Upload a theme and set it as default
  #   upload_theme("/path/to/theme")
  def upload_theme(set_theme_as_default: true)
    theme = RemoteTheme.import_theme_from_directory(theme_dir_from_caller)

    if theme.component
      raise "Uploaded theme is a theme component, please use the `upload_theme_component` method instead."
    end

    theme.set_default! if set_theme_as_default
    theme
  end

  # Invokes a Rake task in a way that is safe for the test environment
  def invoke_rake_task(task_name, *args)
    Rake::Task[task_name].invoke(*args)
  ensure
    Rake::Task[task_name].reenable
  end

  # Uploads a theme component from a directory.
  #
  # @param parent_theme_id [Integer] The ID of the theme to add the theme component to. Defaults to `SiteSetting.default_theme_id`.
  #
  # @return [Theme] The uploaded theme model given by `models/theme.rb`.
  #
  # @example Upload a theme component
  #   upload_theme_component("/path/to/theme_component")
  #
  # @example Upload a theme component and add it to a specific theme
  #   upload_theme_component("/path/to/theme_component", parent_theme_id: 123)
  def upload_theme_component(parent_theme_id: SiteSetting.default_theme_id)
    theme = RemoteTheme.import_theme_from_directory(theme_dir_from_caller)

    if !theme.component
      raise "Uploaded theme is not a theme component, please use the `upload_theme` method instead."
    end

    Theme.find(parent_theme_id).child_themes << theme
    theme
  end

  # Runs named migration for a given theme.
  #
  # @params [Theme] theme The theme to run the migration for.
  # @params [String] migration_name The name of the migration to run.
  #
  # @return [nil]
  #
  # @example
  #   run_theme_migration(theme, "0001-migrate-some-settings")
  def run_theme_migration(theme, migration_name)
    migration_theme_field = theme.theme_fields.find_by(name: migration_name)
    theme.migrate_settings(fields: [migration_theme_field], allow_out_of_sequence_migration: true)
    nil
  end

  private

  def theme_dir_from_caller
    caller.each do |line|
      if (split = line.split(%r{/spec/*/.+_spec.rb})).length > 1
        return split.first
      end
    end
  end
end
