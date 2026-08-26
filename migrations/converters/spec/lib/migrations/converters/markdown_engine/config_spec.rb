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

    it "downcases slugs and tag names for the case-insensitive lookup" do
      expect(config.category_slugs).to eq(%w[support feature])
      expect(config.tag_names).to eq(%w[bug])
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
  # `siteSettings.*` read added to the JavaScript the Bundle loads must be
  # classified here before it silently falls back to `undefined` in V8.
  describe "SETTING_KEYS coverage" do
    it "contains every siteSettings key the bundled markdown JavaScript reads" do
      root = Migrations::Converters::MarkdownEngine.discourse_root
      bundle = Migrations::Converters::MarkdownEngine::Bundle

      files = []
      bundle::MODULE_DIRS.each_key { |dir| files.concat(Dir[File.join(root, dir, "**", "*.js")]) }
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

      keys_read =
        files.flat_map { |file| File.read(file).scan(/siteSettings\.([a-z_0-9]+)/).flatten }.uniq

      expect(keys_read - described_class::SETTING_KEYS).to be_empty
    end
  end
end
