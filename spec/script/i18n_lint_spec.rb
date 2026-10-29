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
    it "accepts {{setting:title}}" do
      errors = errors_for("Some text with {{setting:title}} in it.")
      expect(errors[:invalid_setting_link_format]).to be_empty
      expect(errors[:invalid_interpolation_key_format]).to be_empty
    end

    it "accepts {{setting:s3_upload_bucket}}" do
      errors = errors_for("Some text with {{setting:s3_upload_bucket}} in it.")
      expect(errors[:invalid_setting_link_format]).to be_empty
      expect(errors[:invalid_interpolation_key_format]).to be_empty
    end

    it "accepts {{settings:title,logo}}" do
      errors = errors_for("Some text with {{settings:title,logo}} in it.")
      expect(errors[:invalid_setting_link_format]).to be_empty
      expect(errors[:invalid_interpolation_key_format]).to be_empty
    end

    it "accepts {{settings:title,logo|All required settings}}" do
      errors = errors_for("Some text with {{settings:title,logo|All required settings}} in it.")
      expect(errors[:invalid_setting_link_format]).to be_empty
      expect(errors[:invalid_interpolation_key_format]).to be_empty
    end

    it "accepts {{settings:set_locale_from_cookie,allow_user_locale,title|View them}}" do
      errors =
        errors_for(
          "Some text with {{settings:set_locale_from_cookie,allow_user_locale,title|View them}} in it.",
        )
      expect(errors[:invalid_setting_link_format]).to be_empty
      expect(errors[:invalid_interpolation_key_format]).to be_empty
    end

    it "flags {{setting:Title}} as malformed" do
      errors = errors_for("Some text with {{setting:Title}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # uppercase name

    it "flags {{setting:title }} as malformed" do
      errors = errors_for("Some text with {{setting:title }} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # trailing space

    it "flags {{setting:}} as malformed" do
      errors = errors_for("Some text with {{setting:}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # empty name

    it "flags {{settings:title, logo|label}} as malformed" do
      errors = errors_for("Some text with {{settings:title, logo|label}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # space after comma

    it "flags {{settings:title;logo|label}} as malformed" do
      errors = errors_for("Some text with {{settings:title;logo|label}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # wrong separator

    it "flags {{settings:title,logo|}} as malformed" do
      errors = errors_for("Some text with {{settings:title,logo|}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # empty label

    it "flags {{settings:title,logo|la|bel}} as malformed" do
      errors = errors_for("Some text with {{settings:title,logo|la|bel}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # pipe inside label

    it "flags {{settings:title,logo|la{bel}} as malformed" do
      errors = errors_for("Some text with {{settings:title,logo|la{bel}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # brace inside label

    it "flags {{settings:,title}} as malformed" do
      errors = errors_for("Some text with {{settings:,title}} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # leading comma

    it "flags {{setting:title} as malformed" do
      errors = errors_for("Some text with {{setting:title} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # unclosed singular marker

    it "flags {{settings:title,logo|All} as malformed" do
      errors = errors_for("Some text with {{settings:title,logo|All} in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # unclosed plural marker

    it "flags {{setting:title as malformed" do
      errors = errors_for("Some text with {{setting:title in it.")
      expect(
        errors[:invalid_setting_link_format].presence ||
          errors[:invalid_interpolation_key_format].presence,
      ).to eq(["test_key"])
    end # no closing braces at all

    it "still flags handlebars-style interpolation that isn't a setting marker" do
      expect(errors_for("Hello {{username}}!")[:invalid_interpolation_key_format]).to eq(
        ["test_key"],
      )
    end

    it "accepts %{}-style interpolation untouched" do
      errors = errors_for("Hello %{username}, see {{setting:title}}.")
      expect(errors.values.flatten).to be_empty
    end

    it "agrees with LabelFormatter about {{setting:title}}" do
      text = "Some text with {{setting:title}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:s3_upload_bucket}}" do
      text = "Some text with {{setting:s3_upload_bucket}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo}}" do
      text = "Some text with {{settings:title,logo}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo|All required settings}}" do
      text = "Some text with {{settings:title,logo|All required settings}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:set_locale_from_cookie,allow_user_locale,title|View them}}" do
      text =
        "Some text with {{settings:set_locale_from_cookie,allow_user_locale,title|View them}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:Title}}" do
      text = "Some text with {{setting:Title}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:title }}" do
      text = "Some text with {{setting:title }} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:}}" do
      text = "Some text with {{setting:}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title, logo|label}}" do
      text = "Some text with {{settings:title, logo|label}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title;logo|label}}" do
      text = "Some text with {{settings:title;logo|label}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo|}}" do
      text = "Some text with {{settings:title,logo|}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo|la|bel}}" do
      text = "Some text with {{settings:title,logo|la|bel}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo|la{bel}}" do
      text = "Some text with {{settings:title,logo|la{bel}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:,title}}" do
      text = "Some text with {{settings:,title}} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:title}" do
      text = "Some text with {{setting:title} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{settings:title,logo|All}" do
      text = "Some text with {{settings:title,logo|All} in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end

    it "agrees with LabelFormatter about {{setting:title" do
      text = "Some text with {{setting:title in it."

      lint_accepts = errors_for(text).values.flatten.empty?
      formatter_expands = SiteSettings::LabelFormatter.expand_setting_links(text) != text

      expect(lint_accepts).to eq(formatter_expands)
    end
  end
end
