# frozen_string_literal: true

# System spec for capturing homepage screenshots across the two core themes
# (Foundation and Horizon) × light/dark color modes. Skipped by default — run via:
#
#   TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
#
# Themes are applied per-request via `?preview_theme_id=` so we don't mutate the
# default theme — no cache clears, no teardown needed.
#
# Optional env vars:
#   SCREENSHOTS_DIR     — output directory (default: tmp/theme-screenshots)
#   SCREENSHOTS_PATH    — path to visit (default: /). Special sentinel:
#                         `/t/random` resolves to a randomly-picked fabricated topic.
#   SCREENSHOTS_MODES   — comma-separated modes (default: light,dark)
#   SCREENSHOTS_AS      — who to sign in as: anonymous|user|admin (default: anonymous)
#   SCREENSHOTS_DEVICES — comma-separated devices (default: desktop,mobile). Mobile
#                         uses the Playwright WebKit driver with an iPhone UA so
#                         Discourse's server-side mobile detection kicks in.
THEMES = [
  { name: "foundation", id: Theme::CORE_THEMES["foundation"] },
  { name: "horizon", id: Theme::CORE_THEMES["horizon"] },
].freeze

DEVICES = (ENV["SCREENSHOTS_DEVICES"] || "desktop,mobile").split(",").map(&:strip).freeze

describe "Theme screenshots" do
  before { skip "Set TAKE_SCREENSHOTS=1 to run this spec" if ENV["TAKE_SCREENSHOTS"] != "1" }

  fab!(:admin)
  fab!(:user)

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

  let(:output_dir) do
    dir = ENV["SCREENSHOTS_DIR"] || Rails.root.join("tmp/theme-screenshots").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:target_path) do
    raw = ENV["SCREENSHOTS_PATH"] || "/"
    case raw
    when "/t/random"
      topics.sample.relative_url
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

  let(:signed_in_user) do
    case sign_in_as
    when "admin"
      admin
    when "user"
      user
    end
  end

  let(:modes) { (ENV["SCREENSHOTS_MODES"] || "light,dark").split(",").map(&:strip).map(&:to_sym) }

  let(:sign_in_as) { (ENV["SCREENSHOTS_AS"] || "anonymous").downcase.strip }

  before do
    SiteSetting.global_notice = ""
    SiteSetting.login_required = false

    # `preview_theme_id` requires the theme to be user-selectable for anonymous /
    # regular users (staff can always preview). Flip both core themes on so the
    # spec works across all sign-in modes.
    Theme.where(id: THEMES.map { |t| t[:id] }).update_all(user_selectable: true)

    # `db/fixtures/600_themes.rb` (which calls SystemThemesManager.sync!) only
    # runs on `rake db:seed`, and the dev-mode initializer (999-themes.rb) is
    # gated on Rails.env.development?. So in a fresh test DB, Horizon will
    # be missing its color definitions.
    #
    # Sync the core themes here to materialize the ThemeFields. Idempotent; the
    # writes are rolled back with the test transaction, so it won't pollute the
    # DB for unrelated specs.
    THEMES.each { |t| SystemThemesManager.sync_theme!(t[:name]) }

    # `SiteIconManager.<icon>_url` caches the fully-qualified URL (e.g.
    # `mobile_logo_url`) in a DistributedCache on first access. If that first
    # access happens before `setup_system_test` sets `force_hostname` / `port`,
    # the cached URL hardcodes `http://test.localhost` with no port — which the
    # WebKit driver used for mobile can't resolve, so the mobile logo renders
    # as a broken image. Flush the cache here so URLs are regenerated with the
    # live Capybara host/port.
    SiteIconManager.clear_cache!

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
    THEMES.each do |theme|
      modes.each do |mode|
        emulate_color_scheme(mode)
        visit preview_url(theme[:id])

        wait_for_network_idle
        hide_preview_notice

        role_suffix = sign_in_as == "anonymous" ? "" : "-#{sign_in_as}"
        filename = File.join(output_dir, "#{theme[:name]}-#{mode}-#{device}#{role_suffix}.png")
        full_page_screenshot(filename)
        puts "📸 Saved: #{filename}"
      end
    end
  end

  def preview_url(theme_id)
    separator = target_path.include?("?") ? "&" : "?"
    "#{target_path}#{separator}preview_theme_id=#{theme_id}"
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
