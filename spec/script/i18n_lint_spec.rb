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
    shared_examples "i18n lint for marker" do |marker|
      it "accepts #{marker}" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(errors[:invalid_setting_link_format]).to be_empty
        expect(errors[:invalid_interpolation_key_format]).to be_empty
      end
    end

    include_examples "i18n lint for marker", "{{setting:title}}"
    include_examples "i18n lint for marker", "{{setting:s3_upload_bucket}}"
    include_examples "i18n lint for marker", "{{settings:title,logo}}"
    include_examples "i18n lint for marker", "{{settings:title,logo|All required settings}}"
    include_examples "i18n lint for marker",
                     "{{settings:set_locale_from_cookie,allow_user_locale,title|View them}}"

    shared_examples "i18n lint for marker (2)" do |marker|
      it "flags #{marker} as malformed" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(
          errors[:invalid_setting_link_format].presence ||
            errors[:invalid_interpolation_key_format].presence,
        ).to eq(["test_key"])
      end
    end

    include_examples "i18n lint for marker (2)", "{{setting:Title}}" # uppercase name
    include_examples "i18n lint for marker (2)", "{{setting:title }}" # trailing space
    include_examples "i18n lint for marker (2)", "{{setting:}}" # empty name
    include_examples "i18n lint for marker (2)", "{{settings:title, logo|label}}" # space after comma
    include_examples "i18n lint for marker (2)", "{{settings:title;logo|label}}" # wrong separator
    include_examples "i18n lint for marker (2)", "{{settings:title,logo|}}" # empty label
    include_examples "i18n lint for marker (2)", "{{settings:title,logo|la|bel}}" # pipe inside label
    include_examples "i18n lint for marker (2)", "{{settings:title,logo|la{bel}}" # brace inside label
    include_examples "i18n lint for marker (2)", "{{settings:,title}}" # leading comma
    include_examples "i18n lint for marker (2)", "{{setting:title}" # unclosed singular marker
    include_examples "i18n lint for marker (2)", "{{settings:title,logo|All}" # unclosed plural marker
    include_examples "i18n lint for marker (2)", "{{setting:title" # no closing braces at all

    it "still flags handlebars-style interpolation that isn't a setting marker" do
      expect(errors_for("Hello {{username}}!")[:invalid_interpolation_key_format]).to eq(
        ["test_key"],
      )
    end

    it "accepts %{}-style interpolation untouched" do
      errors = errors_for("Hello %{username}, see {{setting:title}}.")
      expect(errors.values.flatten).to be_empty
    end

    shared_examples "i18n lint for marker (3)" do |marker|
      it "agrees with LabelFormatter about #{marker}" do
        text = "Some text with #{marker} in it."

        lint_accepts = errors_for(text).values.flatten.empty?
        formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

        expect(lint_accepts).to eq(formatter_expands)
      end
    end

    include_examples "i18n lint for marker (3)", "{{setting:title}}"
    include_examples "i18n lint for marker (3)", "{{setting:s3_upload_bucket}}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo}}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo|All required settings}}"
    include_examples "i18n lint for marker (3)",
                     "{{settings:set_locale_from_cookie,allow_user_locale,title|View them}}"
    include_examples "i18n lint for marker (3)", "{{setting:Title}}"
    include_examples "i18n lint for marker (3)", "{{setting:title }}"
    include_examples "i18n lint for marker (3)", "{{setting:}}"
    include_examples "i18n lint for marker (3)", "{{settings:title, logo|label}}"
    include_examples "i18n lint for marker (3)", "{{settings:title;logo|label}}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo|}}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo|la|bel}}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo|la{bel}}"
    include_examples "i18n lint for marker (3)", "{{settings:,title}}"
    include_examples "i18n lint for marker (3)", "{{setting:title}"
    include_examples "i18n lint for marker (3)", "{{settings:title,logo|All}"
    include_examples "i18n lint for marker (3)", "{{setting:title"
  end
end
