# frozen_string_literal: true

def extract_locale(path)
  path[/\.([^.]{2,})\.yml$/, 1]
end

def is_yaml_compatible?(english, translated)
  english.each do |k, v|
    if translated.has_key?(k)
      if Hash === v
        if Hash === translated[k]
          return false unless is_yaml_compatible?(v, translated[k])
        end
      else
        return false unless v.class == translated[k].class
      end
    end
  end

  true
end

def load_yaml(path)
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
    YAML.load_file(path, aliases: true)
  else
    YAML.load_file(path)
  end
end

def deep_each(input, key_seq: [], &block)
  queue = input.to_a

  while queue.size > 0
    key, value = queue.shift
    if value.is_a?(Hash)
      queue.concat(value.transform_keys { |k| "#{key}.#{k}" }.to_a)
    elsif value.is_a?(Array)
      value.each_with_index { |item, index| queue << ["#{key}.#{index}", item] }
    elsif value
      block.call(key, value)
    end
  end
end

def friendly_path(path)
  path.sub(Rails.root.to_s, "")
end

RSpec.describe "i18n integrity checks" do
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

  Dir["#{Rails.root}/config/locales/{client,server}.*.yml"].each do |path|
    it "does not contain invalid interpolation keys for '#{friendly_path(path)}'" do
      matches = File.read(path).scan(/%\{([^a-zA-Z\s]+)\}|\{\{([^a-zA-Z\s]+)\}\}/)
      matches.flatten!
      matches.compact!
      matches.uniq!
      expect(matches).to eq([])
    end
  end

  Dir["#{Rails.root}/config/locales/client.*.yml"].each do |path|
    it "has valid client YAML for '#{friendly_path(path)}'" do
      yaml = load_yaml(path)
      locale = extract_locale(path)

      expect(yaml.keys).to eq([locale])

      expect(yaml[locale]["js"]).to be

      if !LocaleSiteSetting.fallback_locale(locale)
        expect(yaml[locale]["admin_js"]).to be
        expect(yaml[locale]["wizard_js"]).to be
      end
    end
  end

  Dir["#{Rails.root}/**/locale*/*.en.yml"].each do |english_path|
    english_yaml = load_yaml(english_path)["en"]

    context(friendly_path(english_path)) do
      it "has no duplicate keys" do
        english_duplicates = DuplicateKeyFinder.new.find_duplicates(english_path)
        expect(english_duplicates).to be_empty
      end

      {
        "color scheme" => "color palette",
        "private message" => "personal message",
      }.each do |phrase, recommendation|
        it "does not contain the banned phrase '#{phrase}' (use '#{recommendation}' instead)" do
          deep_each(english_yaml) do |key, value|
            expect(value&.downcase).not_to include(phrase), "[en.#{key}]: #{value}"
          end
        end
      end
    end

    Dir[english_path.sub(".en.yml", ".*.yml")].each do |path|
      next if path[".en.yml"]

      context(friendly_path(path)) do
        locale = extract_locale(path)
        yaml = load_yaml(path)

        it "has no duplicate keys" do
          duplicates = DuplicateKeyFinder.new.find_duplicates(path)
          expect(duplicates).to be_empty
        end

        it "does not overwrite another locale" do
          expect(yaml.keys).to eq([locale])
        end

        unless path["transliterate"]
          it "is compatible with english" do
            expect(is_yaml_compatible?(english_yaml, yaml)).to eq(true)
          end
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
