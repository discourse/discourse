# frozen_string_literal: true

require "tmpdir"

load Rails.root.join("script/i18n_lint.rb")

RSpec.describe LocaleFileValidator do
  def errors_for(value)
    Dir.mktmpdir("i18n-lint") do |dir|
      path = File.join(dir, "server.en.yml")
      File.write(path, { "en" => { "test_key" => value } }.to_yaml)

      validator = described_class.new(path)
      validator.has_errors?
      validator.instance_variable_get(:@errors)
    end
  end

  def errors_for_file(filename, content, english: nil)
    Dir.mktmpdir("i18n-lint") do |dir|
      path = File.join(dir, filename)
      File.write(path, content)

      validator = described_class.new(path, english:)
      validator.has_errors?
      validator.instance_variable_get(:@errors)
    end
  end

  it "flags duplicate keys" do
    errors = errors_for_file("server.en.yml", "en:\n  a: one\n  a: two\n")
    expect(errors[:duplicate_keys]).to eq(["a"])
  end

  it "flags a top-level key that is not the locale from the file name" do
    errors = errors_for_file("server.de.yml", "fr:\n  a: un\n", english: { "a" => "one" })
    expect(errors[:invalid_top_level_key]).to be_present
  end

  it "flags interpolation keys made only of digits or symbols" do
    errors =
      errors_for_file("server.de.yml", "de:\n  a: '%{1} {{0}}'\n", english: { "a" => "%{x}" })
    expect(errors[:invalid_interpolation_keys]).to eq(["a: %{1}, {{0}}"])
  end

  it "flags translations whose structure differs from English" do
    english = { "group" => { "one" => "one", "other" => "other" }, "text" => "text" }
    errors = errors_for_file("server.de.yml", "de:\n  group: eins\n  text:\n    a: b\n", english:)
    expect(errors[:incompatible_with_english]).to contain_exactly("group", "text")
  end

  it "accepts a translation with no keys, which falls back to English" do
    errors = errors_for_file("server.de.yml", "de:\n", english: { "a" => "one" })
    expect(errors.values.flatten).to be_empty
  end

  it "applies the English content rules only to English files" do
    errors =
      errors_for_file("server.de.yml", "de:\n  a: 'Hallo {{user}}'\n", english: { "a" => "x" })
    expect(errors.values.flatten).to be_empty
  end

  it "flags core client files without their required sections" do
    Dir.mktmpdir("i18n-lint") do |dir|
      path = File.join(dir, "client.en.yml")
      File.write(path, "en:\n  js:\n    a: b\n")
      validator = described_class.new(path)

      stub_const(described_class, :CORE_LOCALES_DIR, File.realpath(dir)) { validator.has_errors? }

      errors = validator.instance_variable_get(:@errors)
      expect(errors[:missing_client_sections]).to eq(["wizard_js"])
    end
  end

  describe "setting link markers" do
    VALID_MARKERS = [
      "{{setting:title}}",
      "{{setting:s3_upload_bucket}}",
      "{{settings:title,logo}}",
      "{{settings:title,logo|All required settings}}",
      "{{settings:set_locale_from_cookie,allow_user_locale,title|View them}}",
    ]

    MALFORMED_MARKERS = [
      "{{setting:Title}}", # uppercase name
      "{{setting:title }}", # trailing space
      "{{setting:}}", # empty name
      "{{settings:title, logo|label}}", # space after comma
      "{{settings:title;logo|label}}", # wrong separator
      "{{settings:title,logo|}}", # empty label
      "{{settings:title,logo|la|bel}}", # pipe inside label
      "{{settings:title,logo|la{bel}}", # brace inside label
      "{{settings:,title}}", # leading comma
      "{{setting:title}", # unclosed singular marker
      "{{settings:title,logo|All}", # unclosed plural marker
      "{{setting:title", # no closing braces at all
    ]

    # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
    VALID_MARKERS.each do |marker|
      it "accepts #{marker}" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(errors[:invalid_setting_link_format]).to be_empty
        expect(errors[:invalid_interpolation_key_format]).to be_empty
      end
    end
    # rubocop:enable Discourse/NoIterationOverRSpecDefinitions

    # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
    MALFORMED_MARKERS.each do |marker|
      it "flags #{marker} as malformed" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(
          errors[:invalid_setting_link_format].presence ||
            errors[:invalid_interpolation_key_format].presence,
        ).to eq(["test_key"])
      end
    end
    # rubocop:enable Discourse/NoIterationOverRSpecDefinitions

    it "still flags handlebars-style interpolation that isn't a setting marker" do
      expect(errors_for("Hello {{username}}!")[:invalid_interpolation_key_format]).to eq(
        ["test_key"],
      )
    end

    it "accepts %{}-style interpolation untouched" do
      errors = errors_for("Hello %{username}, see {{setting:title}}.")
      expect(errors.values.flatten).to be_empty
    end

    # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
    (VALID_MARKERS + MALFORMED_MARKERS).each do |marker|
      it "agrees with LabelFormatter about #{marker}" do
        text = "Some text with #{marker} in it."

        lint_accepts = errors_for(text).values.flatten.empty?
        formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

        expect(lint_accepts).to eq(formatter_expands)
      end
    end
    # rubocop:enable Discourse/NoIterationOverRSpecDefinitions
  end
end

RSpec.describe I18nLinter do
  it "checks the translations next to each English file" do
    Dir.mktmpdir("i18n-lint") do |dir|
      File.write(File.join(dir, "server.en.yml"), "en:\n  a: one\n")
      File.write(File.join(dir, "server.de.yml"), "de:\n  a: eins\n  a: zwei\n")

      linter = described_class.new(["#{dir}/*.en.yml"])
      expect { linter.run }.to raise_error(SystemExit).and output(/server\.de\.yml/).to_stdout
    end
  end
end
