# frozen_string_literal: true

# System spec for capturing screenshots and comparing results across themes and branches
# Run via:
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

DEVICES = (ENV["SCREENSHOTS_DEVICES"] || "desktop,mobile").split(",").map(&:strip).freeze

DEFAULT_SCREENSHOT_ROUTES = %w[
  /latest
  /categories
  /chat
  /new-topic
  /admin
  /my/summary
  /c/announcements
  /groups
  /t/random
].freeze

describe "Theme screenshots" do
  include ChatSystemHelpers if defined?(ChatSystemHelpers)

  before { skip "Set TAKE_SCREENSHOTS=1 to run this spec" if ENV["TAKE_SCREENSHOTS"] != "1" }

  fab!(:admin)
  fab!(:user)
  fab!(:user_2, :user)

  fab!(:category) { Fabricate(:category, name: "Announcements") }
  fab!(:category_2, :category)

  # We could potentially move these to post fabricators
  # Keeping them here now so that this spec is self-contained
  TOPIC_POSTS = [
    { title: "Welcome to our community discussion forum", raw: <<~MD },
        ## Welcome! :wave:

        We're so glad you're here. This community is a place to **share ideas**, ask questions,
        and connect with others who share your interests.
      MD
    { title: "New release: performance improvements and bug fixes", raw: <<~MD },
        ## What's new in v3.4

        This release focuses on **speed** and **stability**. Here's what changed:

        ### Performance
        - Topic list loads ~40% faster on large forums
        - Reduced memory usage on long-running workers
        - Image lazy-loading now enabled by default

        ### Bug fixes
        - Fixed an edge case where notifications were duplicated after a merge
        - Resolved a rendering issue with `code blocks` inside quotes
        - Corrected timestamp display in timezones east of UTC+8

        ```ruby
        # Enable the new loader in your settings
        SiteSetting.experimental_fast_loader = true
        ```

        Full changelog available in the [release notes](#).
      MD
    { title: "How do I customize my notification preferences?", raw: <<~MD },
        I've been getting a lot of emails lately and I'd like to fine-tune which ones I receive.
        I know there's a preferences page but I'm not sure which settings do what.

        Specifically, I'm trying to:

        1. Stop receiving emails for *every* reply in threads I've participated in
        2. Still get notified when someone **mentions me directly**
        3. Keep daily digest emails, but switch them to weekly

        I've looked at **Preferences → Notifications** but some options aren't obvious.
        Is there documentation for what each setting does?

        Thanks in advance!
      MD
    { title: "Looking for feedback on the updated navigation design", raw: <<~MD },
        Hey everyone — we've been working on a redesign of the top navigation and would love
        your thoughts before we roll it out broadly.

        ### What's changing

        | Before | After |
        |--------|-------|
        | Fixed sidebar, always visible | Collapsible sidebar with toggle |
        | Categories in top bar | Categories moved to sidebar |
        | Single search icon | Expanded search bar on desktop |

        ### Our goals
        - Reduce visual clutter on smaller screens
        - Make categories more discoverable
        - Free up vertical space for content

        > We know navigation changes can be disruptive — that's exactly why we want feedback
        > *before* shipping, not after.

        What do you think? Drop your reactions below.
      MD
    { title: "Please read before posting: community guidelines", raw: <<~MD },
        ## Community guidelines

        To keep this a welcoming space for everyone, we ask that all members follow these guidelines.

        ### Be respectful
        Treat others as you'd like to be treated. Disagreement is fine; personal attacks are not.
        This includes **sarcasm** and passive-aggressive language.

        ### Stay on topic
        Post in the most relevant category. If you're unsure, use *Uncategorized* and a moderator
        will help move it.

        ### Search before posting
        Use the search bar — common questions are often already answered. It saves everyone time.
      MD
  ].freeze

  fab!(:topics) do
    cats = [category, category_2]
    TOPIC_POSTS.each_with_index.map do |spec, i|
      topic = Fabricate(:topic, title: spec[:title], category: cats[i % cats.size])
      Fabricate(:post, topic: topic, raw: spec[:raw])
      topic
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

  let(:raw_dir) do
    dir = File.join(output_dir, "raw")
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:modes) { (ENV["SCREENSHOTS_MODES"] || "light,dark").split(",").map(&:strip).map(&:to_sym) }

  let(:sign_in_as) { (ENV["SCREENSHOTS_AS"] || "admin").downcase.strip }

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
    core = Theme::CORE_THEMES.map { |name, id| { name: name, id: id } }
    base =
      if ENV["SCREENSHOTS_THEMES"].present?
        requested = ENV["SCREENSHOTS_THEMES"].split(",").map { |n| n.downcase.strip }
        core.select { |t| requested.include?(t[:name]) }
      else
        core
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
      paths = (raw == "all") ? DEFAULT_SCREENSHOT_ROUTES : raw.split(",").map(&:strip)
      paths.map { |p| expand_path(p) }
    elsif ENV["SCREENSHOTS_PATH"].present?
      [expand_path(ENV["SCREENSHOTS_PATH"].strip)]
    else
      DEFAULT_SCREENSHOT_ROUTES.map { |p| expand_path(p) }
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
    themes.each do |t|
      SystemThemesManager.sync_theme!(t[:name]) if Theme::CORE_THEMES.key?(t[:name])
    end

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
            File.join(raw_dir, "#{device}-#{theme[:name]}#{role_suffix}-#{mode}#{path_suffix}.png")
          full_page_screenshot(filename, device: device)
          puts "📸 Saved: #{filename}"

          comparisons[mode][slug] << { label: theme[:name], file: filename }
        end
      end
    end

    create_html_comparison(device, comparisons) if themes.size > 1
    create_baseline_comparison(device) if ENV["SCREENSHOTS_BASELINE_DIR"].present?
  end

  def create_html_comparison(device, comparisons)
    role_suffix = sign_in_as == "anonymous" ? "" : "-#{sign_in_as}"
    all_labels =
      comparisons
        .values
        .flat_map { |paths| paths.values.flat_map { |e| e.map { |x| x[:label] } } }
        .uniq
    html_path = File.join(output_dir, "compare-#{device}#{role_suffix}.html")

    pages =
      comparisons.flat_map do |mode, paths|
        paths.map do |slug, entries|
          label = paths.size > 1 || comparisons.size > 1 ? "#{slug} · #{mode}" : mode.to_s
          { label: label, entries: entries }
        end
      end

    write_comparison_html(html_path, "#{device.capitalize} · #{all_labels.join(" vs ")}", pages)
    puts "🌐 Comparison: file://#{html_path}"
  end

  def create_baseline_comparison(device)
    baseline_src = ENV["SCREENSHOTS_BASELINE_DIR"].to_s.strip
    return unless File.directory?(baseline_src)

    role_suffix = sign_in_as == "anonymous" ? "" : "-#{sign_in_as}"
    baseline_label = ENV["SCREENSHOTS_BASELINE_LABEL"].presence || File.basename(baseline_src)

    baseline_dest = File.join(output_dir, "_baseline")
    FileUtils.mkdir_p(baseline_dest)

    by_mode = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

    Dir
      .glob(File.join(raw_dir, "#{device}-*.png"))
      .sort
      .each do |current_file|
        filename = File.basename(current_file)
        src = File.join(baseline_src, filename)
        next unless File.exist?(src)

        dest = File.join(baseline_dest, filename)
        FileUtils.cp(src, dest) unless File.exist?(dest)

        mode = modes.find { |m| filename.include?("-#{m}") } || modes.first
        slug_match = filename.match(/-#{mode}(?:-([^.]+))?\.png$/)
        slug = slug_match&.[](1) || "root"

        by_mode[mode][slug] << { label: baseline_label, file: dest }
        by_mode[mode][slug] << { label: "current", file: current_file }
      end

    return if by_mode.empty?

    pages =
      by_mode.flat_map do |mode, paths|
        paths.map do |slug, entries|
          label = paths.size > 1 || by_mode.size > 1 ? "#{slug} · #{mode}" : mode.to_s
          { label: label, entries: entries }
        end
      end

    html_path = File.join(output_dir, "compare-#{device}#{role_suffix}-vs-baseline.html")
    write_comparison_html(html_path, "#{device.capitalize} · #{baseline_label} vs current", pages)
    puts "🌐 Baseline comparison: file://#{html_path}"
  end

  # Generates a self-contained HTML comparison page with prev/next pagination.
  # pages: [{label:, entries: [{label:, file:}, ...]}] — file paths may be anywhere on disk.
  def write_comparison_html(html_path, title, pages)
    html_dir = File.dirname(html_path)
    total = pages.size
    first_label = pages.first&.fetch(:label, "") || ""

    pages_html =
      pages
        .each_with_index
        .map do |page, i|
          active = i == 0 ? " active" : ""
          cols =
            page[:entries].map do |entry|
              rel = Pathname.new(entry[:file]).relative_path_from(Pathname.new(html_dir)).to_s
              <<~COL
                <div class="col">
                  <div class="col-label">#{entry[:label]}</div>
                  <img src="#{rel}" loading="lazy">
                </div>
              COL
            end
          %(<div class="page#{active}" data-label="#{page[:label]}">\n#{cols.join}\n</div>)
        end
        .join("\n")

    File.write(html_path, <<~HTML)
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>#{title}</title>
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #111; color: #eee; font-family: system-ui, sans-serif; }
        nav { display: flex; align-items: center; gap: 8px; padding: 7px 12px; background: #1a1a1a; border-bottom: 1px solid #222; position: sticky; top: 0; z-index: 20; }
        .btn { padding: 3px 10px; background: #2a2a2a; color: #ccc; border: 1px solid #444; border-radius: 4px; cursor: pointer; font-size: 14px; line-height: 1.4; }
        .btn:disabled { opacity: 0.3; cursor: default; }
        #counter { font-size: 12px; color: #666; min-width: 44px; text-align: center; }
        #page-label { font-size: 13px; color: #ddd; }
        #title { font-size: 12px; color: #555; margin-left: auto; }
        .page { display: none; flex-direction: row; gap: 2px; }
        .page.active { display: flex; }
        .col { flex: 1; min-width: 0; }
        .col-label { position: sticky; top: 40px; background: #1a1a1a; padding: 5px 10px; font-size: 12px; font-weight: 600; text-align: center; border-bottom: 1px solid #222; z-index: 10; }
        img { width: 100%; display: block; }
        </style>
        </head>
        <body>
        <nav>
          <button class="btn" id="btn-prev" onclick="go(-1)" disabled>&#8592;</button>
          <span id="counter">1 / #{total}</span>
          <button class="btn" id="btn-next" onclick="go(1)"#{total <= 1 ? " disabled" : ""}>&#8594;</button>
          <span id="page-label">#{first_label}</span>
          <span id="title">#{title}</span>
        </nav>
        #{pages_html}
        <script>
        var idx = 0;
        var pages = document.querySelectorAll('.page');
        function go(dir) {
          idx = Math.max(0, Math.min(pages.length - 1, idx + dir));
          pages.forEach(function(p) { p.classList.remove('active'); });
          pages[idx].classList.add('active');
          document.getElementById('counter').textContent = (idx + 1) + ' / ' + pages.length;
          document.getElementById('page-label').textContent = pages[idx].dataset.label;
          document.getElementById('btn-prev').disabled = idx === 0;
          document.getElementById('btn-next').disabled = idx === pages.length - 1;
        }
        document.addEventListener('keydown', function(e) {
          if (e.key === 'ArrowLeft') go(-1);
          if (e.key === 'ArrowRight') go(1);
        });
        </script>
        </body>
        </html>
      HTML
  end

  # Converts a site-relative path into a safe filename segment.
  def path_slug(path)
    slug = path.delete_prefix("/").gsub("/", "-").gsub(/[^a-zA-Z0-9\-_]/, "")
    slug.empty? ? "root" : slug
  end

  def expand_path(raw)
    case raw
    when "/t/random"
      t = topics.sample
      "/t/#{t.slug}/#{t.id}"
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
      pw_page.wait_for_load_state(state: "networkidle", timeout: 10_000)
    rescue Playwright::TimeoutError
      # page is visually complete; a stray background request is still open
    end
  end

  # Desktop: full-page screenshot. Mobile: viewport-only at a fixed height (844px)
  # so that comparisons are 1:1 regardless of page content length.
  def full_page_screenshot(path, device:)
    page.driver.with_playwright_page do |pw_page|
      if device == "mobile"
        vp = pw_page.viewport_size
        pw_page.set_viewport_size(width: vp[:width], height: 844)
        pw_page.screenshot(path: path)
      else
        pw_page.screenshot(path: path, fullPage: true)
      end
    end
  end

  # The `?preview_theme_id=` query param surfaces a global notice ("You are
  # currently previewing a theme…") that we don't want in screenshots.
  def hide_preview_notice
    page.driver.with_playwright_page do |pw_page|
      pw_page.add_style_tag(content: "#global-notice-theme-preview { display: none !important; }")
    end
  end
end
