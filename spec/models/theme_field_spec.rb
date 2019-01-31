# encoding: utf-8

require 'rails_helper'

describe ThemeField do
  after(:all) do
    ThemeField.destroy_all
  end

  describe "scope: find_by_theme_ids" do
    it "returns result in the specified order" do
      theme = Fabricate(:theme)
      theme2 = Fabricate(:theme)
      theme3 = Fabricate(:theme)

      (0..1).each do |num|
        ThemeField.create!(theme: theme, target_id: num, name: "header", value: "<a>html</a>")
        ThemeField.create!(theme: theme2, target_id: num, name: "header", value: "<a>html</a>")
        ThemeField.create!(theme: theme3, target_id: num, name: "header", value: "<a>html</a>")
      end

      expect(ThemeField.find_by_theme_ids(
        [theme3.id, theme.id, theme2.id]
      ).pluck(:theme_id)).to eq(
        [theme3.id, theme3.id, theme.id, theme.id, theme2.id, theme2.id]
      )
    end
  end

  it 'does not insert a script tag when there are no inline script' do
    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "body_tag", value: '<div>new div</div>')
    expect(theme_field.value_baked).to_not include('<script')
  end

  it 'only extracts inline javascript to an external file' do
    html = <<~HTML
    <script type="text/discourse-plugin" version="0.8">
      var a = "inline discourse plugin";
    </script>
    <script type="text/template" data-template="custom-template">
      <div>custom script type</div>
    </script>
    <script>
      var b = "inline raw script";
    </script>
    <script type="texT/jAvasCripT">
      var c = "text/javascript";
    </script>
    <script type="application/javascript">
      var d = "application/javascript";
    </script>
    <script src="/external-script.js"></script>
    HTML

    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "header", value: html)

    expect(theme_field.value_baked).to include("<script src=\"#{theme_field.javascript_cache.url}\"></script>")
    expect(theme_field.value_baked).to include("external-script.js")
    expect(theme_field.value_baked).to include('<script type="text/template"')
    expect(theme_field.javascript_cache.content).to include('a = "inline discourse plugin"')
    expect(theme_field.javascript_cache.content).to include('b = "inline raw script"')
    expect(theme_field.javascript_cache.content).to include('c = "text/javascript"')
    expect(theme_field.javascript_cache.content).to include('d = "application/javascript"')
  end

  it 'adds newlines between the extracted javascripts' do
    html = <<~HTML
    <script>var a = 10</script>
    <script>var b = 10</script>
    HTML

    extracted = <<~JavaScript
    var a = 10
    var b = 10
    JavaScript

    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "header", value: html)

    expect(theme_field.javascript_cache.content).to include(extracted)
  end

  it "correctly extracts and generates errors for transpiled js" do
    html = <<HTML
<script type="text/discourse-plugin" version="0.8">
   badJavaScript(;
</script>
HTML

    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "header", value: html)
    expect(field.error).not_to eq(nil)
    expect(field.value_baked).to include("<script src=\"#{field.javascript_cache.url}\"></script>")
    expect(field.javascript_cache.content).to include("Theme Transpilation Error:")

    field.update!(value: '')
    expect(field.error).to eq(nil)
  end

  it "allows us to use theme settings in handlebars templates" do
    html = <<HTML
<script type='text/x-handlebars' data-template-name='my-template'>
    <div class="testing-div">{{themeSettings.string_setting}}</div>
</script>
HTML

    ThemeField.create!(theme_id: 1, target_id: 3, name: "yaml", value: "string_setting: \"test text \\\" 123!\"")
    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "head_tag", value: html)
    javascript_cache = theme_field.javascript_cache

    expect(theme_field.value_baked).to include("<script src=\"#{javascript_cache.url}\"></script>")
    expect(javascript_cache.content).to include("testing-div")
    expect(javascript_cache.content).to include("string_setting")
    expect(javascript_cache.content).to include("test text \\\" 123!")
  end

  it "correctly generates errors for transpiled css" do
    css = "body {"
    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "scss", value: css)
    field.reload
    expect(field.error).not_to eq(nil)
    field.value = "body {color: blue};"
    field.save!
    field.reload

    expect(field.error).to eq(nil)
  end

  def create_upload_theme_field!(name)
    ThemeField.create!(
      theme_id: 1,
      target_id: 0,
      value: "",
      type_id: ThemeField.types[:theme_upload_var],
      name: name,
    )
  end

  it "ensures we don't use invalid SCSS variable names" do
    expect { create_upload_theme_field!("42") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { create_upload_theme_field!("a42") }.not_to raise_error
  end

  def get_fixture(type)
    File.read("#{Rails.root}/spec/fixtures/theme_settings/#{type}_settings.yaml")
  end

  def create_yaml_field(value)
    field = ThemeField.create!(theme_id: 1, target_id: Theme.targets[:settings], name: "yaml", value: value)
    field.reload
    field
  end

  let(:key) { "themes.settings_errors" }

  it "generates errors for bad YAML" do
    yaml = "invalid_setting 5"
    field = create_yaml_field(yaml)
    expect(field.error).to eq(I18n.t("#{key}.invalid_yaml"))

    field.value = "valid_setting: true"
    field.save!
    field.reload
    expect(field.error).to eq(nil)
  end

  it "generates errors when default value's type doesn't match setting type" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_not_match_type", name: "no_match_setting"))
  end

  it "generates errors when no default value is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_value_missing", name: "no_default_setting"))
  end

  it "generates errors when invalid type is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.data_type_not_a_number", name: "invalid_type_setting"))
  end

  it "generates errors when default value is not within allowed range" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(I18n.t("#{key}.default_out_range", name: "default_out_of_range"))
    expect(field.error).to include(I18n.t("#{key}.default_out_range", name: "string_default_out_of_range"))
  end

  it "works correctly when valid yaml is provided" do
    field = create_yaml_field(get_fixture("valid"))
    expect(field.error).to be_nil
  end

  describe "locale fields" do

    let!(:theme) { Fabricate(:theme) }
    let!(:theme2) { Fabricate(:theme) }
    let!(:theme3) { Fabricate(:theme) }

    let!(:en1) {
      ThemeField.create!(theme: theme, target_id: Theme.targets[:translations], name: "en",
                         value: { en: { somestring1: "helloworld", group: { key1: "enval1" } } }
                                  .deep_stringify_keys.to_yaml
      )
    }
    let!(:fr1) {
      ThemeField.create!(theme: theme, target_id: Theme.targets[:translations], name: "fr",
                         value: { fr: { somestring1: "bonjourworld", group: { key2: "frval2" } } }
                                  .deep_stringify_keys.to_yaml
      )
    }
    let!(:fr2) { ThemeField.create!(theme: theme2, target_id: Theme.targets[:translations], name: "fr", value: "") }
    let!(:en2) { ThemeField.create!(theme: theme2, target_id: Theme.targets[:translations], name: "en", value: "") }
    let!(:ca3) { ThemeField.create!(theme: theme3, target_id: Theme.targets[:translations], name: "ca", value: "") }
    let!(:en3) { ThemeField.create!(theme: theme3, target_id: Theme.targets[:translations], name: "en", value: "") }

    describe "scopes" do
      it "find_locale_fields returns results in the correct order" do
        expect(ThemeField.find_locale_fields(
          [theme3.id, theme.id, theme2.id], ["en", "fr"]
        )).to eq([en3, en1, fr1, en2, fr2])
      end

      it "find_first_locale_fields returns only the first locale for each theme" do
        expect(ThemeField.find_first_locale_fields(
          [theme3.id, theme.id, theme2.id], ["ca", "en", "fr"]
        )).to eq([ca3, en1, en2])
      end
    end

    describe "#raw_translation_data" do
      it "errors if the top level key is incorrect" do
        fr1.update(value: { wrongkey: { somestring1: "bonjourworld" } }.deep_stringify_keys.to_yaml)
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if there are multiple top level keys" do
        fr1.update(value: { fr: { somestring1: "bonjourworld" }, otherkey: "hello" }.deep_stringify_keys.to_yaml)
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if YAML includes arrays" do
        fr1.update(value: { fr: ["val1", "val2"] }.deep_stringify_keys.to_yaml)
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if YAML has invalid syntax" do
        fr1.update(value: "fr: 'valuewithoutclosequote")
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end
    end

    describe "#translation_data" do
      it "loads correctly" do
        expect(fr1.translation_data).to eq(
          fr: { somestring1: "bonjourworld", group: { key2: "frval2" } },
          en: { somestring1: "helloworld", group: { key1: "enval1" } }
        )
      end

      it "raises errors for the current locale" do
        fr1.update(value: { wrongkey: "hello" }.deep_stringify_keys.to_yaml)
        expect { fr1.translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "doesn't raise errors for the fallback locale" do
        en1.update(value: { wrongkey: "hello" }.deep_stringify_keys.to_yaml)
        expect(fr1.translation_data).to eq(
          fr: { somestring1: "bonjourworld", group: { key2: "frval2" } }
        )
      end

      it "merges any overrides" do
        # Overrides in the current locale (so in tests that will be english)
        theme.update_translation("group.key1", "overriddentest1")
        theme.reload
        expect(fr1.translation_data).to eq(
          fr: { somestring1: "bonjourworld", group: { key2: "frval2" } },
          en: { somestring1: "helloworld", group: { key1: "overriddentest1" } }
        )
      end
    end

    describe "javascript cache" do
      it "is generated correctly" do
        fr1.ensure_baked!
        expect(fr1.value_baked).to include("<script src='#{fr1.javascript_cache.url}'></script>")
        expect(fr1.javascript_cache.content).to include("bonjourworld")
        expect(fr1.javascript_cache.content).to include("helloworld")
        expect(fr1.javascript_cache.content).to include("enval1")
      end
    end

    describe "prefix injection" do
      it "injects into JS" do
        html = <<~HTML
        <script type="text/discourse-plugin" version="0.8">
          var a = "inline discourse plugin";
        </script>
        HTML

        theme_field = ThemeField.create!(theme_id: theme.id, target_id: 0, name: "head_tag", value: html)
        javascript_cache = theme_field.javascript_cache
        expect(javascript_cache.content).to include("inline discourse plugin")
        expect(javascript_cache.content).to include("theme_translations.#{theme.id}.")
      end
    end
  end

end
