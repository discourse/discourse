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
    shared_examples "a valid setting link marker" do |marker|
      it "accepts #{marker}" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(errors[:invalid_setting_link_format]).to be_empty
        expect(errors[:invalid_interpolation_key_format]).to be_empty
      end
    end

    it_behaves_like "a valid setting link marker", "{{setting:title}}"

    it_behaves_like "a valid setting link marker", "{{setting:s3_upload_bucket}}"

    it_behaves_like "a valid setting link marker", "{{settings:title,logo}}"

    it_behaves_like "a valid setting link marker", "{{settings:title,logo|All required settings}}"

    it_behaves_like "a valid setting link marker",
                    "{{settings:set_locale_from_cookie,allow_user_locale,title|View them}}"

    shared_examples "a malformed setting link marker" do |marker|
      it "flags #{marker} as malformed" do
        errors = errors_for("Some text with #{marker} in it.")
        expect(
          errors[:invalid_setting_link_format].presence ||
            errors[:invalid_interpolation_key_format].presence,
        ).to eq(["test_key"])
      end
    end

    # uppercase name
    it_behaves_like "a malformed setting link marker", "{{setting:Title}}"

    # trailing space
    it_behaves_like "a malformed setting link marker", "{{setting:title }}"

    # empty name
    it_behaves_like "a malformed setting link marker", "{{setting:}}"

    # space after comma
    it_behaves_like "a malformed setting link marker", "{{settings:title, logo|label}}"

    # wrong separator
    it_behaves_like "a malformed setting link marker", "{{settings:title;logo|label}}"

    # empty label
    it_behaves_like "a malformed setting link marker", "{{settings:title,logo|}}"

    # pipe inside label
    it_behaves_like "a malformed setting link marker", "{{settings:title,logo|la|bel}}"

    # brace inside label
    it_behaves_like "a malformed setting link marker", "{{settings:title,logo|la{bel}}"

    # leading comma
    it_behaves_like "a malformed setting link marker", "{{settings:,title}}"

    # unclosed singular marker
    it_behaves_like "a malformed setting link marker", "{{setting:title}"

    # unclosed plural marker
    it_behaves_like "a malformed setting link marker", "{{settings:title,logo|All}"

    # no closing braces at all
    it_behaves_like "a malformed setting link marker", "{{setting:title"

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
