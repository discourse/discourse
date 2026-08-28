# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownEngine::Config do
  subject(:config) { described_class.new }

  describe "default settings" do
    it "reads the checkout's YAML defaults" do
      expect(config.settings["enable_mentions"]).to be(true)
      expect(config.settings["unicode_usernames"]).to be(false)
      expect(config.settings["poll_maximum_options"]).to be_an(Integer)
      expect(config.settings["markdown_linkify_tlds"]).to be_a(String)
    end

    it "covers every setting key" do
      expect(config.settings.keys).to match_array(described_class::SETTING_KEYS)
    end
  end

  describe "source overrides" do
    subject(:config) do
      described_class.new(
        source_settings: {
          "enable_mentions" => "f",
          "poll_maximum_options" => "5",
          "emoji_set" => "noto",
          "not_a_markdown_setting" => "ignored",
          "max_username_length" => 42,
        },
      )
    end

    it "coerces stringly-typed database values against the default's type" do
      expect(config.settings["enable_mentions"]).to be(false)
      expect(config.settings["poll_maximum_options"]).to eq(5)
      expect(config.settings["emoji_set"]).to eq("noto")
    end

    it "ignores settings the markdown pipeline does not read" do
      expect(config.settings).not_to have_key("not_a_markdown_setting")
      expect(config.settings).not_to have_key("max_username_length")
    end
  end

  describe "name sets" do
    subject(:config) do
      described_class.new(
        category_slugs: %w[Support FEATURE],
        tag_names: %w[Bug],
        custom_emoji_names: %w[partyparrot],
      )
    end

    it "normalizes slugs and tag names the way the constructs do" do
      expect(config.category_slugs).to eq(%w[support feature])
      expect(config.tag_names).to eq(%w[bug])
    end

    it "applies NFC, so a decomposed configured name matches its composed form" do
      config = described_class.new(tag_names: ["café"])
      expect(config.tag_names).to eq([Migrations::NameNormalizer.normalize("café")])
    end

    it "builds a custom emoji map keyed by name" do
      expect(config.custom_emoji).to eq("partyparrot" => "/images/emoji/custom/partyparrot.png")
    end
  end

  describe "avatar sizes" do
    it "parses the pipe-separated YAML default into integers" do
      expect(config.avatar_sizes).to all(be_an(Integer))
      expect(config.avatar_sizes).not_to be_empty
    end
  end

  # The engine only receives the settings named in SETTING_KEYS, so any
  # `siteSettings` read added to the JavaScript the Bundle loads must be
  # classified here before it silently falls back to `undefined` in V8.
  describe "SETTING_KEYS coverage" do
    # Recognized read idioms, each capturing the key(s) read. Anything that
    # mentions `siteSettings` and matches none of these fails the second
    # example: an alias or a new idiom must be added here, not silently skipped.
    let(:property_read) { /siteSettings\??\.([A-Za-z_0-9]+)/ }
    let(:bracket_read) { /siteSettings\??\[\s*["']([A-Za-z_0-9]+)["']\s*\]/ }
    let(:destructuring_read) { /\{([^{}]*)\}\s*=[^=;\n]*siteSettings/ }
    # A callback parameter named `siteSettings` declares the object, it reads
    # no key — the reads happen through the other idioms in the body.
    let(:parameter_declaration) { /[(,]\s*siteSettings\s*(?=[,)])/ }

    def bundled_js_files
      root = Migrations::Converters::MarkdownEngine.discourse_root
      bundle = Migrations::Converters::MarkdownEngine::Bundle

      files = []
      # Only the JavaScript sources — the core-bundle globs also cover build
      # configs and the lockfile, which read no site settings.
      bundle::CORE_BUNDLE_GLOBS.each do |pattern|
        files.concat(Dir.glob(pattern, base: root).grep(/\.js\z/).map { |f| File.join(root, f) })
      end
      bundle::CORE_MARKDOWN_PLUGINS.each do |plugin|
        files.concat(
          Dir[
            File.join(
              root,
              "plugins",
              plugin,
              "assets/javascripts/**/discourse-markdown/**/*.{js,js.es6}",
            )
          ],
        )
      end
      files
    end

    def keys_read_in(files)
      files.flat_map do |file|
        source = File.read(file)
        source.scan(property_read).flatten + source.scan(bracket_read).flatten +
          source
            .scan(destructuring_read)
            .flatten
            .flat_map { |names| names.split(",").map { |name| name[/[A-Za-z_0-9]+/] } }
            .compact
      end
    end

    # `avatar_sizes` is covered by the dedicated AVATAR_SIZES_KEY: it rides
    # the options as `avatar_sizes`, and the processor's helpers shim hands
    # it back to avatar-utils under a `siteSettings` reading.
    def covered_keys
      described_class::SETTING_KEYS + [described_class::AVATAR_SIZES_KEY]
    end

    it "contains every siteSettings key the bundled markdown JavaScript reads" do
      expect(keys_read_in(bundled_js_files).uniq - covered_keys).to be_empty
    end

    # The supported plugin list is an allowlist because of this: each listed
    # plugin's own reads are covered, so its rules run with the source
    # site's settings. A plugin added to the list without extending
    # SETTING_KEYS fails here by name.
    it "covers each supported plugin's own siteSettings reads" do
      root = Migrations::Converters::MarkdownEngine.discourse_root

      Migrations::Converters::MarkdownEngine::Bundle::CORE_MARKDOWN_PLUGINS.each do |plugin|
        files =
          Dir[
            File.join(
              root,
              "plugins",
              plugin,
              "assets/javascripts/**/discourse-markdown/**/*.{js,js.es6}",
            )
          ]
        # A supported plugin with no markdown files would make this example
        # pass with nothing checked — that happens when the plugin's file
        # layout changes, and it means the plugin is no longer bundled.
        expect(files).not_to be_empty,
        "#{plugin} has no markdown feature files under the known path"
        missing = keys_read_in(files).uniq - covered_keys
        expect(missing).to be_empty,
        "#{plugin} reads siteSettings keys SETTING_KEYS does not cover: #{missing.inspect}"
      end
    end

    it "recognizes every siteSettings mention, so aliases can't hide a read" do
      unrecognized =
        bundled_js_files.flat_map do |file|
          File
            .read(file)
            .each_line
            .with_index(1)
            .filter_map do |line, number|
              line = line.sub(%r{//.*}, "")
              next unless line.include?("siteSettings")
              # Object shorthand on its own line: a multiline destructuring or
              # parameter list declaring the object, same as the inline forms.
              next if line.match?(/\A\s*siteSettings,?\s*\z/)

              # An object-literal key (`{ siteSettings: {} }`) supplies the
              # object; it reads no key.
              stripped =
                line
                  .gsub(property_read, "")
                  .gsub(bracket_read, "")
                  .gsub(destructuring_read, "")
                  .gsub(parameter_declaration, "(")
                  .gsub(/siteSettings\s*:/, "")
              # What remains is a mention none of the read idioms account
              # for: a bare reference (an alias assignment, a helper call
              # forwarding the object) whose later reads this static check
              # cannot see.
              "#{file}:#{number}: #{line.strip}" if stripped.include?("siteSettings")
            end
        end

      expect(unrecognized).to be_empty,
      -> { "extend the recognized siteSettings read idioms:\n#{unrecognized.join("\n")}" }
    end
  end
end
