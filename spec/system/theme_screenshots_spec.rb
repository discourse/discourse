# frozen_string_literal: true

# System spec for capturing screenshots across the two core themes
# (Foundation and Horizon) × light/dark color modes. Skipped by default — run via:
#
#   TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
#
# Themes are applied per-request via `?preview_theme_id=` so we don't mutate the
# default theme — no cache clears, no teardown needed.
#
# Optional env vars:
#   SCREENSHOTS_DIR         — output directory (default: tmp/theme-screenshots)
#   SCREENSHOTS_PATH        — single path to visit (default: /). Special sentinels:
#                             `/t/random` resolves to a randomly-picked fabricated topic.
#                             `/my/*` is expanded to `/u/:username/*` for signed-in users.
#   SCREENSHOTS_PATHS       — comma-separated paths, or "all" for the full route list:
#                               /latest, /categories, /groups, /admin, /my/summary,
#                               /chat, /new-topic
#                             When set, overrides SCREENSHOTS_PATH. Note that /admin
#                             requires SCREENSHOTS_AS=admin; /chat and /my/* require user or admin.
#   SCREENSHOTS_MODES       — comma-separated modes (default: light,dark)
#   SCREENSHOTS_AS          — who to sign in as: anonymous|user|admin (default: anonymous)
#   SCREENSHOTS_DEVICES     — comma-separated devices (default: desktop,mobile). Mobile
#                             uses the Playwright WebKit driver with an iPhone UA so
#                             Discourse's server-side mobile detection kicks in.
#   SCREENSHOTS_THEMES      — comma-separated theme names to capture (default: foundation,horizon)
#   SCREENSHOTS_THEME_URL   — git URL of a remote theme to install into the test DB and add to
#                             the capture matrix. Use SCREENSHOTS_THEME_NAME for the filename
#                             label (default: repo name). Set SCREENSHOTS_THEMES= (empty) to
#                             capture only the remote theme.
#   SCREENSHOTS_THEME_ID    — ID of a theme already present in the test DB to add to the matrix.
#                             Combine with SCREENSHOTS_THEME_NAME for a nicer filename label.
ALL_THEMES = [
  { name: "foundation", id: Theme::CORE_THEMES["foundation"] },
  { name: "horizon", id: Theme::CORE_THEMES["horizon"] },
].freeze

DEVICES = (ENV["SCREENSHOTS_DEVICES"] || "desktop,mobile").split(",").map(&:strip).freeze

ALL_SCREENSHOT_ROUTES = %w[/latest /categories /groups /admin /my/summary /chat /new-topic].freeze

describe "Theme screenshots" do
  include ChatSystemHelpers if defined?(ChatSystemHelpers)

  before { skip "Set TAKE_SCREENSHOTS=1 to run this spec" if ENV["TAKE_SCREENSHOTS"] != "1" }

  fab!(:admin)
  fab!(:user)
  fab!(:user_2, :user)

  fab!(:category) { Fabricate(:category, name: "Announcements") }
  fab!(:category_2, :category)

  fab!(:topics) do
    titles = [
      "Welcome to our community discussion forum",
      "New release: performance improvements and bug fixes",
      "How do I customize my notification preferences?",
      "Looking for feedback on the updated navigation design",
      "Please read before posting: community guidelines",
    ]
    cats = [category, category_2]
    titles.each_with_index.map do |title, i|
      post = Fabricate(:post, topic: Fabricate(:topic, title: title, category: cats[i % cats.size]))
      post.topic
    end
  end

  fab!(:chat_channel) do
    if defined?(Chat)
      channel = Fabricate(:chat_channel, name: "General", chatable: category)
      channel.add(admin)
      channel.add(user)
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: admin,
        message: "Hey everyone, welcome!",
      )
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user,
        message: "Thanks for joining the community.",
      )
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: admin,
        message: "Don't forget to check out the latest announcements.",
      )
      channel
    end
  end

  fab!(:dm_channels) do
    if defined?(Chat)
      dm1 =
        Fabricate(:direct_message_channel, users: [admin, user]).tap do |ch|
          Fabricate(
            :chat_message,
            chat_channel: ch,
            user: admin,
            message: "Hey, quick question about the announcement post.",
          )
          Fabricate(:chat_message, chat_channel: ch, user: user, message: "Sure, what's up?")
          Fabricate(
            :chat_message,
            chat_channel: ch,
            user: admin,
            message: "Can you review the draft before we publish?",
          )
        end
      dm2 =
        Fabricate(:direct_message_channel, users: [admin, user_2]).tap do |ch|
          Fabricate(
            :chat_message,
            chat_channel: ch,
            user: user_2,
            message: "Just checking in — are you free for the sync tomorrow?",
          )
          Fabricate(:chat_message, chat_channel: ch, user: admin, message: "Yes, I'll be there!")
        end
      [dm1, dm2]
    end
  end

  let(:output_dir) do
    dir = ENV["SCREENSHOTS_DIR"] || Rails.root.join("tmp/theme-screenshots").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:modes) { (ENV["SCREENSHOTS_MODES"] || "light,dark").split(",").map(&:strip).map(&:to_sym) }

  let(:sign_in_as) { (ENV["SCREENSHOTS_AS"] || "anonymous").downcase.strip }

  let(:signed_in_user) do
    case sign_in_as
    when "admin"
      admin
    when "user"
      user
    end
  end

  # Builds the list of themes to capture. Starts from the built-in constant list
  # (filtered by SCREENSHOTS_THEMES), then appends any extra theme passed via
  # SCREENSHOTS_THEME_ID (must already be installed in the dev DB).
  let(:themes) do
    base =
      if ENV["SCREENSHOTS_THEMES"].present?
        requested = ENV["SCREENSHOTS_THEMES"].split(",").map { |n| n.downcase.strip }
        ALL_THEMES.select { |t| requested.include?(t[:name]) }
      else
        ALL_THEMES.dup
      end

    if (url = ENV["SCREENSHOTS_THEME_URL"].presence)
      name = ENV["SCREENSHOTS_THEME_NAME"].presence || File.basename(url.chomp("/"), ".git")
      tmpdir = Dir.mktmpdir("discourse_theme_screenshot_")
      system("git", "clone", "--depth", "1", url, tmpdir, exception: true)
      theme = RemoteTheme.import_theme_from_directory(tmpdir)
      theme.update!(user_selectable: true)
      Stylesheet::Manager.clear_theme_cache!
      base = base + [{ name: name, id: theme.id }]
    elsif (id = ENV["SCREENSHOTS_THEME_ID"].presence&.to_i)
      name = ENV["SCREENSHOTS_THEME_NAME"].presence || "theme-#{id}"
      base = base + [{ name: name, id: id }]
    end

    base
  end

  # Returns the list of site-relative paths to visit. Driven by SCREENSHOTS_PATHS
  # (comma-separated or "all") or falls back to SCREENSHOTS_PATH / "/".
  let(:target_paths) do
    if ENV["SCREENSHOTS_PATHS"].present?
      raw = ENV["SCREENSHOTS_PATHS"].strip
      paths = (raw == "all") ? ALL_SCREENSHOT_ROUTES : raw.split(",").map(&:strip)
      paths.map { |p| expand_path(p) }
    else
      [expand_path(ENV["SCREENSHOTS_PATH"] || "/")]
    end
  end

  before do
    SiteSetting.global_notice = ""
    SiteSetting.login_required = false

    # `preview_theme_id` requires the theme to be user-selectable for anonymous /
    # regular users (staff can always preview). Flip built-in core themes on so the
    # spec works across all sign-in modes.
    Theme.where(id: themes.map { |t| t[:id] }).update_all(user_selectable: true)

    # `db/fixtures/600_themes.rb` (which calls SystemThemesManager.sync!) only
    # runs on `rake db:seed`, and the dev-mode initializer (999-themes.rb) is
    # gated on Rails.env.development?. So in a fresh test DB, Horizon will
    # be missing its color definitions.
    #
    # Sync the built-in core themes here to materialize the ThemeFields. Idempotent; the
    # writes are rolled back with the test transaction, so it won't pollute the
    # DB for unrelated specs.
    (themes & ALL_THEMES).each { |t| SystemThemesManager.sync_theme!(t[:name]) }

    # `SiteIconManager.<icon>_url` caches the fully-qualified URL (e.g.
    # `mobile_logo_url`) in a DistributedCache on first access. If that first
    # access happens before `setup_system_test` sets `force_hostname` / `port`,
    # the cached URL hardcodes `http://test.localhost` with no port — which the
    # WebKit driver used for mobile can't resolve, so the mobile logo renders
    # as a broken image. Flush the cache here so URLs are regenerated with the
    # live Capybara host/port.
    SiteIconManager.clear_cache!

    chat_system_bootstrap(admin, [chat_channel].compact) if defined?(Chat)

    sign_in(signed_in_user) if signed_in_user
  end

  it "captures desktop screenshots", if: DEVICES.include?("desktop") do
    capture_matrix(device: "desktop")
  end

  it "captures mobile screenshots", :mobile, if: DEVICES.include?("mobile") do
    capture_matrix(device: "mobile")
  end

  private

  def capture_matrix(device:)
    # comparisons[mode][path_slug] = [{label:, file:}, ...]
    comparisons = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

    themes.each do |theme|
      modes.each do |mode|
        emulate_color_scheme(mode)
        target_paths.each do |path|
          visit preview_url(path, theme[:id])

          wait_for_network_idle
          hide_preview_notice

          role_suffix = sign_in_as == "anonymous" ? "" : "-#{sign_in_as}"
          slug = path_slug(path)
          path_suffix = target_paths.size > 1 ? "-#{slug}" : ""
          filename =
            File.join(
              output_dir,
              "#{device}-#{theme[:name]}#{role_suffix}-#{mode}#{path_suffix}.png",
            )
          full_page_screenshot(filename)
          puts "📸 Saved: #{filename}"

          comparisons[mode][slug] << { label: theme[:name], file: filename }
        end
      end
    end

    create_comparisons(device, comparisons) if themes.size > 1
  end

  def create_comparisons(device, comparisons)
    role_suffix = sign_in_as == "anonymous" ? "" : "-#{sign_in_as}"

    comparisons.each do |mode, paths|
      paths.each do |slug, entries|
        path_suffix = comparisons.values.any? { |p| p.size > 1 } ? "-#{slug}" : ""
        output = File.join(output_dir, "compare-#{device}#{role_suffix}-#{mode}#{path_suffix}.png")

        args = %w[magick montage]
        entries.each { |e| args.push("-label", e[:label], e[:file]) }
        args.push(
          "-tile",
          "#{entries.size}x1",
          "-geometry",
          "+4+4",
          "-pointsize",
          "28",
          "-background",
          "#1a1a1a",
          "-fill",
          "white",
          output,
        )

        system(*args)
        puts "🖼️  Comparison: #{output}"
      end
    end
  end

  # Converts a site-relative path into a safe filename segment.
  def path_slug(path)
    slug = path.delete_prefix("/").gsub("/", "-").gsub(/[^a-zA-Z0-9\-_]/, "")
    slug.empty? ? "root" : slug
  end

  def expand_path(raw)
    case raw
    when "/t/random"
      topics.sample.relative_url
    when "/chat"
      raise "/chat requires SCREENSHOTS_AS=user or admin" if sign_in_as == "anonymous"
      raw
    when %r{\A/my(/.*)?\z}
      # `UsersController#my_redirect` does a bare `redirect_to` that drops any
      # query string, so `/my/anything?preview_theme_id=X` loses the preview.
      # Expand to the canonical `/u/:username/...` path here so the query
      # survives. Requires a signed-in user.
      username = signed_in_user&.encoded_username
      raise "/my/* requires SCREENSHOTS_AS=user or admin" if username.blank?
      "/u/#{username}#{Regexp.last_match(1)}"
    else
      raw
    end
  end

  def preview_url(path, theme_id)
    separator = path.include?("?") ? "&" : "?"
    "#{path}#{separator}preview_theme_id=#{theme_id}"
  end

  def emulate_color_scheme(mode)
    page.driver.with_playwright_page { |pw_page| pw_page.emulate_media(colorScheme: mode.to_s) }
  end

  # Wait for the page to stop making network requests instead of polling for a
  # route-specific selector. Works across /, /categories, /t/..., /wizard, etc.
  # without needing to teach the spec about each page's DOM shape.
  #
  # MessageBus long-polling holds an HTTP request open indefinitely, which
  # would prevent `networkidle` from ever settling — abort those requests at
  # the network layer on first use.
  def wait_for_network_idle
    page.driver.with_playwright_page do |pw_page|
      unless @message_bus_blocked
        pw_page.route(%r{/message-bus/}, ->(route, _request) { route.abort })
        @message_bus_blocked = true
      end
      pw_page.wait_for_load_state(state: "networkidle", timeout: 5_000)
    end
  end

  def full_page_screenshot(path)
    page.driver.with_playwright_page { |pw_page| pw_page.screenshot(path: path, fullPage: true) }
  end

  # The `?preview_theme_id=` query param surfaces a global notice ("You are
  # currently previewing a theme…") that we don't want in screenshots.
  def hide_preview_notice
    page.driver.with_playwright_page do |pw_page|
      pw_page.add_style_tag(content: "#global-notice-theme-preview { display: none !important; }")
    end
  end
end
