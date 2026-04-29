# frozen_string_literal: true

# System spec for capturing screenshots at marked points in other system specs.
# Run via:
#
#   TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
#
# Discovers all system specs that call `screenshot_here` and runs them under
# each combination of theme × device × color mode, then generates a single
# HTML comparison page with tabs for device and color mode.
#
# Optional env vars:
#   SCREENSHOTS_DIR         — output directory (default: tmp/theme-screenshots)
#   SCREENSHOTS_MODES       — comma-separated modes (default: light,dark)
#   SCREENSHOTS_DEVICES     — comma-separated devices (default: desktop,mobile)
#   SCREENSHOTS_THEMES      — comma-separated theme names (default: foundation,horizon)
#   SCREENSHOTS_THEME_URL   — git URL of a remote theme to install into the test DB
#   SCREENSHOTS_THEME_NAME  — filename label for the remote theme (default: repo name)
#   SCREENSHOTS_THEME_ID    — ID of a theme already present in the test DB

DEVICES = (ENV["SCREENSHOTS_DEVICES"] || "desktop,mobile").split(",").map(&:strip).freeze

describe "Theme screenshots" do
  include ChatSystemHelpers if defined?(ChatSystemHelpers)

  before { skip "Set TAKE_SCREENSHOTS=1 to run this spec" if ENV["TAKE_SCREENSHOTS"] != "1" }

  fab!(:admin)
  fab!(:user)
  fab!(:user_2, :user)

  fab!(:category) { Fabricate(:category, name: "Announcements") }
  fab!(:category_2, :category)

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

  let(:modes) { (ENV["SCREENSHOTS_MODES"] || "light,dark").split(",").map(&:strip) }

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

  before do
    Theme.where(id: themes.map { |t| t[:id] }).update_all(user_selectable: true)

    themes.each do |t|
      SystemThemesManager.sync_theme!(t[:name]) if Theme::CORE_THEMES.key?(t[:name])
    end

    SiteIconManager.clear_cache!

    allow(TopicUser).to receive(:track_visit!)
  end

  it "captures screenshots" do
    run_marker_matrix(device: "desktop") if DEVICES.include?("desktop")

    run_marker_matrix(device: "mobile") if DEVICES.include?("mobile")

    generate_comparison_html
  end

  private

  def discover_marker_specs
    Dir
      .glob(Rails.root.join("spec/system/**/*.rb").to_s)
      .reject { |f| File.realpath(f) == File.realpath(__FILE__) }
      .select { |f| File.read(f).include?("screenshot_here") }
  end

  def run_marker_matrix(device:)
    specs = discover_marker_specs
    if specs.empty?
      puts "No specs with screenshot_here markers found."
      return
    end

    puts "Found #{specs.size} spec(s) with markers: #{specs.map { |s| File.basename(s) }.join(", ")}"

    marker_groups = load_marker_groups(specs)
    filter_marker_examples(marker_groups, specs, device)
    filter_device_split(marker_groups, device)
    apply_device_metadata(marker_groups, device)

    # `group.run` sets `RSpec.current_example` per inner example and leaves it
    # `nil` when the group finishes. The outer example's after-hooks (e.g.
    # rails_helper's `extra_failure_lines`) read it, so restore it after each
    # inner run.
    outer_example = RSpec.current_example
    begin
      themes.each do |theme|
        modes.each do |mode|
          with_screenshot_env(theme: theme, mode: mode, device: device) do
            marker_groups.each do |group|
              group.run(RSpec.configuration.reporter)
              RSpec.current_example = outer_example
            end
          end
        end
      end
    ensure
      RSpec.current_example = outer_example
      cleanup_marker_groups(marker_groups)
    end
  end

  # Loads each marker spec file via `load` so its `describe` blocks register new
  # example groups in `RSpec.world`. Returns just the groups added by these files
  # so the matrix loop can run them and the cleanup step can remove them.
  #
  # Spec authors don't have to remember `include ThemeScreenshotMarker` —
  # discovery is by `screenshot_here` text match, and we auto-include the
  # module so the call resolves in nested contexts and shared_examples.
  def load_marker_groups(spec_files)
    groups = []
    spec_files.each do |spec_file|
      before = RSpec.world.example_groups.dup
      load spec_file
      new_groups = RSpec.world.example_groups - before
      new_groups.each do |g|
        g.include(ThemeScreenshotMarker) if g.included_modules.exclude?(ThemeScreenshotMarker)
      end
      groups.concat(new_groups)
    end
    groups
  end

  # Marker specs are normal system specs — they have many `it` blocks that don't
  # call `screenshot_here`. Running those wastes time and produces noisy
  # failures (e.g. mobile-incompatible interactions). Strip them down to just
  # the examples that actually capture a screenshot for the current device.
  #
  # Examples whose `screenshot_here` was called with `only: :desktop` (or
  # `:mobile`) are kept only on the matching leg.
  def filter_marker_examples(groups, spec_files, device)
    constraints = spec_files.to_h { |f| [File.expand_path(f), screenshot_example_constraints(f)] }
    groups.each { |g| keep_screenshot_examples(g, constraints, device) }
  end

  # Returns a hash mapping the line number of each `it` / `scenario` / `example`
  # / `specify` block that contains `screenshot_here` to a constraint hash:
  #   { only: :desktop } — call site has `only: :desktop`
  #   { only: nil }     — call site has no constraint
  #
  # If a single example contains multiple `screenshot_here` calls with
  # conflicting constraints, the most permissive (no `only`) wins.
  def screenshot_example_constraints(spec_file)
    lines = File.readlines(spec_file)
    result = {}
    lines.each_with_index do |line, idx|
      next if line.exclude?("screenshot_here")
      only_match = line.match(/only:\s*:(\w+)/)
      only = only_match ? only_match[1].to_sym : nil
      (idx - 1).downto(0) do |i|
        if lines[i] =~ /^\s*(it|scenario|example|specify)\b/
          existing = result[i + 1]
          result[i + 1] = { only: only } if existing.nil? || existing[:only]
          break
        end
      end
    end
    result
  end

  def keep_screenshot_examples(group, constraints_per_file, device)
    group.examples.select! do |ex|
      file = File.expand_path(ex.metadata[:file_path])
      constraint = (constraints_per_file[file] || {})[ex.metadata[:line_number]]
      next false unless constraint
      only = constraint[:only]
      only.nil? || only.to_s == device
    end
    group.children.each { |child| keep_screenshot_examples(child, constraints_per_file, device) }
    group.children.reject! { |child| empty_group?(child) }
  end

  def empty_group?(group)
    group.examples.empty? && group.children.all? { |c| empty_group?(c) }
  end

  # Some specs split their suite by device with sibling contexts — one tagged
  # `mobile: true`, the other left as desktop (e.g. signup_spec's
  # "when desktop" / "when mobile" using shared_examples). Detect that pattern
  # by spotting a group whose children have a mix of mobile and non-mobile
  # metadata, and keep only the side that matches the current leg. Specs
  # without this pattern are unaffected.
  def filter_device_split(groups, device)
    groups.each { |g| filter_device_split_recursively(g, device) }
    groups.reject! { |g| empty_group?(g) }
  end

  def filter_device_split_recursively(group, device)
    group.children.each { |child| filter_device_split_recursively(child, device) }

    has_mobile = group.children.any? { |c| c.metadata[:mobile] }
    has_non_mobile = group.children.any? { |c| !c.metadata[:mobile] }
    return unless has_mobile && has_non_mobile

    if device == "mobile"
      group.children.select! { |c| c.metadata[:mobile] }
    else
      group.children.select! { |c| !c.metadata[:mobile] }
    end
  end

  # The `:mobile` metadata is what triggers the global `before(:each)` hook in
  # rails_helper to switch the Capybara driver to the mobile WebKit driver.
  # Marker specs don't tag themselves `:mobile`, so we stamp it on at runtime
  # when we're in the mobile leg of the matrix.
  def apply_device_metadata(groups, device)
    return unless device == "mobile"
    groups.each { |g| set_mobile_recursively(g) }
  end

  def set_mobile_recursively(group)
    group.metadata[:mobile] = true
    group.examples.each { |ex| ex.metadata[:mobile] = true }
    group.children.each { |child| set_mobile_recursively(child) }
  end

  def cleanup_marker_groups(groups)
    groups.each { |g| RSpec.world.example_groups.delete(g) }
  end

  def with_screenshot_env(theme:, mode:, device:)
    saved = {}
    overrides = {
      "TAKE_SCREENSHOTS" => "1",
      "SCREENSHOTS_DIR" => output_dir,
      "SCREENSHOTS_THEME_ID" => theme[:id].to_s,
      "SCREENSHOTS_THEME_NAME" => theme[:name],
      "SCREENSHOTS_MODE" => mode.to_s,
      "SCREENSHOTS_DEVICE" => device,
    }
    overrides.each do |k, v|
      saved[k] = ENV[k]
      ENV[k] = v
    end
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  # Scans raw_dir for all captured PNGs and builds a single HTML comparison page
  # with tabs for device and color mode, and label-by-label pagination.
  # Called after each device run — the final call sees all screenshots.
  def generate_comparison_html
    theme_names = themes.map { |t| t[:name] }

    # panels[device][mode][label] = [{label: theme_name, file: abs_path}, ...]
    panels =
      Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = [] } } }

    Dir
      .glob(File.join(raw_dir, "*.png"))
      .sort
      .each do |file|
        basename = File.basename(file, ".png")
        DEVICES.each do |device|
          next unless basename.start_with?("#{device}-")
          rest = basename.delete_prefix("#{device}-")
          theme_names.each do |theme_name|
            next unless rest.start_with?("#{theme_name}-")
            rest2 = rest.delete_prefix("#{theme_name}-")
            modes.each do |mode|
              next unless rest2.start_with?("#{mode}-")
              label = rest2.delete_prefix("#{mode}-")
              panels[device][mode][label] << { label: theme_name, file: file }
              break
            end
            break
          end
          break
        end
      end

    return if panels.empty?

    html_path = File.join(output_dir, "compare.html")
    write_comparison_html(html_path, panels)
    puts "🌐 Comparison: file://#{html_path}"
  end

  def write_comparison_html(html_path, panels)
    html_dir = File.dirname(html_path)

    available_devices = DEVICES.select { |d| panels[d].any? }
    available_modes = modes.select { |m| panels.values.any? { |dm| dm[m]&.any? } }
    all_labels = panels.values.flat_map { |modes_h| modes_h.values.flat_map(&:keys) }.uniq

    panels_html =
      available_devices
        .flat_map do |device|
          available_modes.flat_map do |mode|
            all_labels.map do |label|
              entries = panels[device][mode][label]
              next "" if entries.empty?

              cols =
                entries.map do |entry|
                  rel = Pathname.new(entry[:file]).relative_path_from(Pathname.new(html_dir)).to_s
                  <<~COL
                  <div class="col">
                    <div class="col-label">#{entry[:label]}</div>
                    <img src="#{rel}" loading="lazy">
                  </div>
                COL
                end

              panel_id = "panel-#{device}-#{mode}-#{label}"
              <<~PANEL
              <div class="panel" id="#{panel_id}" data-device="#{device}" data-mode="#{mode}" data-label="#{label}">
                #{cols.join}
              </div>
            PANEL
            end
          end
        end
        .join("\n")

    device_tabs_html =
      available_devices
        .map do |d|
          active = d == available_devices.first ? " active" : ""
          %(<button class="tab#{active}" data-device="#{d}" onclick="selectDevice('#{d}')">#{d.capitalize}</button>)
        end
        .join("\n      ")

    mode_tabs_html =
      available_modes
        .map do |m|
          active = m == available_modes.first ? " active" : ""
          %(<button class="tab#{active}" data-mode="#{m}" onclick="selectMode('#{m}')">#{m.capitalize}</button>)
        end
        .join("\n      ")

    panels_json =
      available_devices.flat_map do |device|
        available_modes.flat_map do |mode|
          all_labels.filter_map do |label|
            next if panels[device][mode][label].empty?
            %({ "device": "#{device}", "mode": "#{mode}", "label": "#{label}" })
          end
        end
      end

    File.write(html_path, <<~HTML)
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Theme Screenshots</title>
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #111; color: #eee; font-family: system-ui, sans-serif; display: flex; flex-direction: column; height: 100vh; overflow: hidden; }
        header { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; gap: 8px; padding: 7px 12px; background: #1a1a1a; border-bottom: 1px solid #333; flex-shrink: 0; }
        .header-left { display: flex; align-items: center; gap: 4px; }
        .header-center { display: flex; justify-content: center; }
        .header-right { display: flex; align-items: center; justify-content: flex-end; gap: 6px; }
        .tab-group { display: flex; gap: 4px; }
        .tab { padding: 3px 12px; background: #2a2a2a; color: #888; border: 1px solid #444; border-radius: 4px; cursor: pointer; font-size: 13px; }
        .tab.active { background: #3a3a3a; color: #fff; border-color: #666; }
        .sep { width: 1px; background: #333; height: 22px; margin: 0 4px; }
        .btn { padding: 3px 10px; background: #2a2a2a; color: #ccc; border: 1px solid #444; border-radius: 4px; cursor: pointer; font-size: 14px; line-height: 1.4; }
        .btn:disabled { opacity: 0.3; cursor: default; }
        #counter { font-size: 12px; color: #666; min-width: 44px; text-align: center; }
        #label-display { font-size: 14px; font-weight: 600; color: #fff; text-align: center; letter-spacing: 0.01em; }
        .content { flex: 1; overflow: hidden; }
        .panel { display: none; flex-direction: row; gap: 2px; height: 100%; }
        .panel.active { display: flex; }
        .col { flex: 1; min-width: 0; display: flex; flex-direction: column; }
        .col-label { flex-shrink: 0; background: #1a1a1a; padding: 5px 10px; font-size: 12px; font-weight: 600; text-align: center; border-bottom: 1px solid #222; }
        img { flex: 1; min-height: 0; width: 100%; object-fit: contain; object-position: top center; display: block; }
        </style>
        </head>
        <body>
        <header>
          <div class="header-left">
            <div class="tab-group" id="device-tabs">
              #{device_tabs_html}
            </div>
            <div class="sep"></div>
            <div class="tab-group" id="mode-tabs">
              #{mode_tabs_html}
            </div>
          </div>
          <div class="header-center">
            <span id="label-display"></span>
          </div>
          <div class="header-right">
            <button class="btn" id="btn-prev" onclick="navigate(-1)">&#8592;</button>
            <span id="counter"></span>
            <button class="btn" id="btn-next" onclick="navigate(1)">&#8594;</button>
          </div>
        </header>
        <div class="content">
          #{panels_html}
        </div>
        <script>
        var allPanels = [#{panels_json.join(",\n")}];
        var currentDevice = #{available_devices.first.to_json};
        var currentMode = #{available_modes.first.to_json};
        var labelIndex = 0;

        function filtered() {
          return allPanels.filter(function(p) {
            return p.device === currentDevice && p.mode === currentMode;
          });
        }

        function show() {
          var set = filtered();
          labelIndex = Math.max(0, Math.min(set.length - 1, labelIndex));
          document.querySelectorAll('.panel').forEach(function(el) {
            el.classList.remove('active');
          });
          if (!set.length) return;
          var p = set[labelIndex];
          var el = document.getElementById('panel-' + p.device + '-' + p.mode + '-' + p.label);
          if (el) el.classList.add('active');
          document.getElementById('counter').textContent = (labelIndex + 1) + ' / ' + set.length;
          document.getElementById('label-display').textContent = p.label;
          document.getElementById('btn-prev').disabled = labelIndex === 0;
          document.getElementById('btn-next').disabled = labelIndex === set.length - 1;
        }

        function navigate(dir) {
          labelIndex += dir;
          show();
        }

        function selectDevice(device) {
          currentDevice = device;
          document.querySelectorAll('#device-tabs .tab').forEach(function(t) {
            t.classList.toggle('active', t.dataset.device === device);
          });
          show();
        }

        function selectMode(mode) {
          currentMode = mode;
          document.querySelectorAll('#mode-tabs .tab').forEach(function(t) {
            t.classList.toggle('active', t.dataset.mode === mode);
          });
          show();
        }

        document.addEventListener('keydown', function(e) {
          if (e.key === 'ArrowLeft') navigate(-1);
          if (e.key === 'ArrowRight') navigate(1);
        });

        show();
        </script>
        </body>
        </html>
      HTML
  end
end
