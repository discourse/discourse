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
    ]

    VALID_MARKERS.each do |marker|
      it "accepts #{marker}" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(errors[:invalid_setting_link_format]).to be_empty
        expect(errors[:invalid_interpolation_key_format]).to be_empty
      end
    end

    MALFORMED_MARKERS.each do |marker|
      it "flags #{marker} as malformed" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(
          errors[:invalid_setting_link_format].presence ||
            errors[:invalid_interpolation_key_format].presence,
        ).to eq(["test_key"])
      end
    end

    it "still flags handlebars-style interpolation that isn't a setting marker" do
      expect(errors_for("Hello {{username}}!")[:invalid_interpolation_key_format]).to eq(
        ["test_key"],
      )
    end

    it "accepts %{}-style interpolation untouched" do
      errors = errors_for("Hello %{username}, see {{setting:title}}.")
      expect(errors.values.flatten).to be_empty
    end

    (VALID_MARKERS + MALFORMED_MARKERS).each do |marker|
      it "agrees with LabelFormatter about #{marker}" do
        text = "Some text with #{marker} in it."

        lint_accepts = errors_for(text).values.flatten.empty?
        formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

        expect(lint_accepts).to eq(formatter_expands)
      end
    end
  end
end
