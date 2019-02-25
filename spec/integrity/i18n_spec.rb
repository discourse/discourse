require "rails_helper"
require "i18n/duplicate_key_finder"

def extract_locale(path)
  path[/\.([^.]{2,})\.yml$/, 1]
end

PLURALIZATION_KEYS ||= ['zero', 'one', 'two', 'few', 'many', 'other']

def find_pluralizations(hash, parent_key = '', pluralizations = Hash.new)
  hash.each do |key, value|
    if Hash === value
      current_key = parent_key.blank? ? key : "#{parent_key}.#{key}"
      find_pluralizations(value, current_key, pluralizations)
    elsif PLURALIZATION_KEYS.include? key
      pluralizations[parent_key] = hash
    end
  end

  pluralizations
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

def each_translation(hash, parent_key = '', &block)
  hash.each do |key, value|
    current_key = parent_key.blank? ? key : "#{parent_key}.#{key}"

    if Hash === value
      each_translation(value, current_key, &block)
    else
      yield(current_key, value.to_s)
    end
  end
end

describe "i18n integrity checks" do

  it 'has an i18n key for each Trust Levels' do
    TrustLevel.all.each do |ts|
      expect(ts.name).not_to match(/translation missing/)
    end
  end

  it "has an i18n key for each Site Setting" do
    SiteSetting.all_settings.each do |s|
      next if s[:setting][/^test_/]
      expect(s[:description]).not_to match(/translation missing/)
    end
  end

  it "has an i18n key for each Badge description" do
    Badge.where(system: true).each do |b|
      expect(b.long_description).to be_present
      expect(b.description).to be_present
    end
  end

  Dir["#{Rails.root}/config/locales/{client,server}.*.yml"].each do |path|
    it "does not contain invalid interpolation keys for '#{path}'" do
      matches = File.read(path).scan(/%\{([^a-zA-Z\s]+)\}|\{\{([^a-zA-Z\s]+)\}\}/)
      matches.flatten!
      matches.compact!
      matches.uniq!
      expect(matches).to eq([])
    end
  end

  Dir["#{Rails.root}/config/locales/client.*.yml"].each do |path|
    it "has valid client YAML for '#{path}'" do
      yaml = YAML.load_file(path)
      locale = extract_locale(path)

      expect(yaml.keys).to eq([locale])

      expect(yaml[locale]["js"]).to be
      expect(yaml[locale]["admin_js"]).to be
      # expect(yaml[locale]["wizard_js"]).to be
    end
  end

  Dir["#{Rails.root}/**/locale*/*.en.yml"].each do |english_path|
    english_yaml = YAML.load_file(english_path)["en"]

    context(english_path) do
      it "has no duplicate keys" do
        english_duplicates = DuplicateKeyFinder.new.find_duplicates(english_path)
        expect(english_duplicates).to be_empty
      end

      find_pluralizations(english_yaml).each do |key, hash|
        next if key["messages.restrict_dependent_destroy"]

        it "has valid pluralizations for '#{key}'" do
          expect(hash.keys).to contain_exactly("one", "other")
        end
      end

      context "valid translations" do
        invalid_relative_links = {}
        invalid_relative_image_sources = {}

        each_translation(english_yaml) do |key, value|
          if value.match?(/href\s*=\s*["']\/[^\/]|\]\(\/[^\/]/i)
            invalid_relative_links[key] = value
          elsif value.match?(/src\s*=\s*["']\/[^\/]/i)
            invalid_relative_image_sources[key] = value
          end
        end

        it "uses %{base_url} or %{base_path} for relative links" do
          keys = invalid_relative_links.keys.join("\n")
          expect(invalid_relative_links).to be_empty, "The following keys have relative links, but do not start with %{base_url} or %{base_path}:\n\n#{keys}"
        end

        it "uses %{base_url} or %{base_path} for relative image src" do
          keys = invalid_relative_image_sources.keys.join("\n")
          expect(invalid_relative_image_sources).to be_empty, "The following keys have relative image sources, but do not start with %{base_url} or %{base_path}:\n\n#{keys}"
        end
      end
    end

    Dir[english_path.sub(".en.yml", ".*.yml")].each do |path|
      next if path[".en.yml"]

      context(path) do
        locale = extract_locale(path)
        yaml = YAML.load_file(path)

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
