# frozen_string_literal: true
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

RSpec.describe "i18n integrity checks" do
  def extract_locale(path)
    path[/\.([^.]{2,})\.yml$/, 1]
  end

  def is_yaml_compatible?(english, translated)
    english.all? do |key, value|
      next true unless translated.key?(key)

      translated_value = translated[key]
      if value.is_a?(Hash)
        !translated_value.is_a?(Hash) || is_yaml_compatible?(value, translated_value)
      else
        value.class == translated_value.class
      end
    end
  end

  def load_yaml(path)
    YAML.load_file(path, aliases: true)
  end

  it "has an i18n key for each Site Setting" do
    SiteSetting.all_settings.each do |s|
      next if s[:plugin] == SiteSetting::SAMPLE_TEST_PLUGIN.name
      expect(s[:description]).not_to be_blank
    end
  end

  it "has an i18n key for each Badge description" do
    Badge
      .where(system: true)
      .each do |b|
        expect(b.long_description).to be_present
        expect(b.description).to be_present
      end
  end

  it "has valid interpolation keys in core locale files", :aggregate_failures do
    Dir[Rails.root.join("config/locales/{client,server}.*.yml")].each do |path|
      aggregate_failures(path) do
        matches =
          File.read(path).scan(/%\{([^a-zA-Z\s]+)\}|\{\{([^a-zA-Z\s]+)\}\}/).flatten.compact.uniq
        expect(matches).to eq([]), "#{path}: invalid interpolation keys #{matches.inspect}"
      end
    end
  end

  it "has valid client locale roots and namespaces", :aggregate_failures do
    Dir[Rails.root.join("config/locales/client.*.yml")].each do |path|
      aggregate_failures(path) do
        yaml = load_yaml(path)
        locale = extract_locale(path)
        expect(yaml).to be_a(Hash), "#{path}: expected a locale mapping"
        next unless yaml.is_a?(Hash)

        expect(yaml.keys).to eq([locale]), "#{path}: expected only the #{locale} locale"
        translations = yaml[locale]
        expect(translations).to be_a(Hash), "#{path}: expected client namespaces"
        next unless translations.is_a?(Hash)

        expect(translations["js"]).to be, "#{path}: missing js namespace"
        unless LocaleSiteSetting.fallback_locale(locale)
          expect(translations["admin_js"]).to be, "#{path}: missing admin_js namespace"
        end
        if locale == "en"
          expect(translations["wizard_js"]).to be, "#{path}: missing wizard_js namespace"
        end
      end
    end
  end

  # Batch by reference file to avoid per-translation setup without creating one long-running example.
  Dir[Rails.root.join("**/locale*/*.en.yml")].each do |english_path|
    it "has valid locale YAML for #{english_path}", :aggregate_failures do
      english_yaml = load_yaml(english_path)["en"]
      expect(DuplicateKeyFinder.new.find_duplicates(english_path)).to be_empty

      Dir[english_path.sub(".en.yml", ".*.yml")].each do |path|
        next if path[".en.yml"]

        aggregate_failures(path) do
          yaml = load_yaml(path)
          locale = extract_locale(path)
          duplicates = DuplicateKeyFinder.new.find_duplicates(path)
          expect(duplicates).to be_empty, "#{path}: duplicate keys #{duplicates.inspect}"
          expect(yaml).to be_a(Hash), "#{path}: expected a locale mapping"
          next unless yaml.is_a?(Hash)

          expect(yaml.keys).to eq([locale]), "#{path}: expected only the #{locale} locale"
          next if path["transliterate"]

          # Empty locale files rely entirely on fallback translations.
          translations = yaml[locale] || {}
          expect(translations).to be_a(Hash), "#{path}: expected translations or an empty locale"
          next unless translations.is_a?(Hash)

          expect(is_yaml_compatible?(english_yaml, translations)).to eq(true),
          "#{path}: translation value types differ from #{english_path}"
        end
      end
    end
  end
end

RSpec.describe "fallbacks" do
  before do
    I18n.backend = I18n::Backend::DiscourseI18n.new
    I18n.fallbacks = I18n::Backend::FallbackLocaleList.new
    I18n.reload!
    I18n.init_accelerator!
  end

  it "finds the fallback translation" do
    I18n.backend.store_translations(:en, test: "en test")

    I18n.with_locale("pl_PL") { expect(I18n.t("test")).to eq("en test") }
  end

  context "when in a multi-threaded environment" do
    it "finds the fallback translation" do
      I18n.backend.store_translations(:en, test: "en test")

      thread = Thread.new { I18n.with_locale("pl_PL") { expect(I18n.t("test")).to eq("en test") } }

      begin
        thread.join
      ensure
        thread.exit
      end
    end
  end
end
# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
