# encoding: utf-8
# frozen_string_literal: true

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
    theme_field.ensure_baked!
    expect(theme_field.value_baked).to_not include('<script')
  end

  it 'adds an error when optimized image links are included' do
    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "body_tag", value: <<~HTML)
      <img src="http://mysite.invalid/uploads/default/optimized/1X/6d749a141f513f88f167e750e528515002043da1_2_1282x1000.png"/>
    HTML
    theme_field.ensure_baked!
    expect(theme_field.error).to include(I18n.t("themes.errors.optimized_link"))

    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "scss", value: <<~SCSS)
      body {
        background: url(http://mysite.invalid/uploads/default/optimized/1X/6d749a141f513f88f167e750e528515002043da1_2_1282x1000.png);
      }
    SCSS
    theme_field.ensure_baked!
    expect(theme_field.error).to include(I18n.t("themes.errors.optimized_link"))

    theme_field.update(value: <<~SCSS)
      body {
        background: url(http://notdiscourse.invalid/optimized/my_image.png);
      }
    SCSS
    theme_field.ensure_baked!
    expect(theme_field.error).to eq(nil)
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
    theme_field.ensure_baked!
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
    theme_field.ensure_baked!
    expect(theme_field.javascript_cache.content).to include(extracted)
  end

  it "correctly extracts and generates errors for transpiled js" do
    html = <<HTML
<script type="text/discourse-plugin" version="0.8">
   badJavaScript(;
</script>
HTML

    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "header", value: html)
    field.ensure_baked!
    expect(field.error).not_to eq(nil)
    expect(field.value_baked).to include("<script src=\"#{field.javascript_cache.url}\"></script>")
    expect(field.javascript_cache.content).to include("Theme Transpilation Error:")

    field.update!(value: '')
    field.ensure_baked!
    expect(field.error).to eq(nil)
  end

  it "allows us to use theme settings in handlebars templates" do
    html = <<HTML
<script type='text/x-handlebars' data-template-name='my-template'>
    <div class="testing-div">{{themeSettings.string_setting}}</div>
</script>
HTML

    ThemeField.create!(theme_id: 1, target_id: 3, name: "yaml", value: "string_setting: \"test text \\\" 123!\"").ensure_baked!
    theme_field = ThemeField.create!(theme_id: 1, target_id: 0, name: "head_tag", value: html)
    theme_field.ensure_baked!
    javascript_cache = theme_field.javascript_cache

    expect(theme_field.value_baked).to include("<script src=\"#{javascript_cache.url}\"></script>")
    expect(javascript_cache.content).to include("testing-div")
    expect(javascript_cache.content).to include("string_setting")
    expect(javascript_cache.content).to include("test text \\\" 123!")
  end

  it "correctly generates errors for transpiled css" do
    css = "body {"
    field = ThemeField.create!(theme_id: 1, target_id: 0, name: "scss", value: css)
    field.ensure_baked!
    expect(field.error).not_to eq(nil)
    field.value = "body {color: blue};"
    field.save!
    field.ensure_baked!

    expect(field.error).to eq(nil)
  end

  it "allows importing scss files" do
    theme = Fabricate(:theme)
    main_field = theme.set_field(target: :common, name: :scss, value: ".class1{color: red}\n@import 'rootfile1';")
    theme.set_field(target: :extra_scss, name: "rootfile1", value: ".class2{color:green}\n@import 'foldername/subfile1';")
    theme.set_field(target: :extra_scss, name: "rootfile2", value: ".class3{color:green} ")
    theme.set_field(target: :extra_scss, name: "foldername/subfile1", value: ".class4{color:yellow}\n@import 'subfile2';")
    theme.set_field(target: :extra_scss, name: "foldername/subfile2", value: ".class5{color:yellow}\n@import '../rootfile2';")

    theme.save!
    result = main_field.compile_scss[0]

    expect(result).to include(".class1")
    expect(result).to include(".class2")
    expect(result).to include(".class3")
    expect(result).to include(".class4")
    expect(result).to include(".class5")
  end

  it "correctly handles extra JS fields" do
    theme = Fabricate(:theme)
    js_field = theme.set_field(target: :extra_js, name: "discourse/controllers/discovery.js.es6", value: "import 'discourse/lib/ajax'; console.log('hello');")
    hbs_field = theme.set_field(target: :extra_js, name: "discourse/templates/discovery.hbs", value: "{{hello-world}}")
    raw_hbs_field = theme.set_field(target: :extra_js, name: "discourse/templates/discovery.raw.hbs", value: "{{hello-world}}")
    unknown_field = theme.set_field(target: :extra_js, name: "discourse/controllers/discovery.blah", value: "this wont work")
    theme.save!

    expected_js = <<~JS
      define("discourse/controllers/discovery", ["discourse/lib/ajax"], function () {
        "use strict";

        var __theme_name__ = "#{theme.name}";
        var settings = Discourse.__container__.lookup("service:theme-settings").getObjectForTheme(#{theme.id});
        var themePrefix = function themePrefix(key) {
          return "theme_translations.#{theme.id}." + key;
        };
        console.log('hello');
      });
    JS
    expect(js_field.reload.value_baked).to eq(expected_js.strip)

    expect(hbs_field.reload.value_baked).to include('Ember.TEMPLATES["discovery"]')
    expect(raw_hbs_field.reload.value_baked).to include('Discourse.RAW_TEMPLATES["discovery"]')
    expect(unknown_field.reload.value_baked).to eq("")
    expect(unknown_field.reload.error).to eq(I18n.t("themes.compile_error.unrecognized_extension", extension: "blah"))

    # All together
    expect(theme.javascript_cache.content).to include('Ember.TEMPLATES["discovery"]')
    expect(theme.javascript_cache.content).to include('Discourse.RAW_TEMPLATES["discovery"]')
    expect(theme.javascript_cache.content).to include('define("discourse/controllers/discovery"')
    expect(theme.javascript_cache.content).to include("var settings =")
  end

  def create_upload_theme_field!(name)
    ThemeField.create!(
      theme_id: 1,
      target_id: 0,
      value: "",
      type_id: ThemeField.types[:theme_upload_var],
      name: name,
    ).tap { |tf| tf.ensure_baked! }
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
    field.ensure_baked!
    field
  end

  let(:key) { "themes.settings_errors" }

  it "forces re-transpilation of theme JS when settings YAML changes" do
    theme = Fabricate(:theme)
    settings_field = ThemeField.create!(theme: theme, target_id: Theme.targets[:settings], name: "yaml", value: "setting: 5")

    html = <<~HTML
      <script type="text/discourse-plugin" version="0.8">
        alert(settings.setting);
      </script>
    HTML

    js_field = ThemeField.create!(theme: theme, target_id: ThemeField.types[:html], name: "header", value: html)
    old_value_baked = js_field.value_baked
    settings_field.update!(value: "setting: 66")
    js_field.reload

    expect(js_field.value_baked).to eq(nil)
    js_field.ensure_baked!
    expect(js_field.value_baked).to be_present
    expect(js_field.value_baked).not_to eq(old_value_baked)
  end

  it "generates errors for bad YAML" do
    yaml = "invalid_setting 5"
    field = create_yaml_field(yaml)
    expect(field.error).to eq(I18n.t("#{key}.invalid_yaml"))

    field.value = "valid_setting: true"
    field.save!
    field.ensure_baked!
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
      ThemeField.create!(theme: theme, target_id: Theme.targets[:translations], name: "en_US",
                         value: { en_US: { somestring1: "helloworld", group: { key1: "enval1" } } }
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
    let!(:en2) { ThemeField.create!(theme: theme2, target_id: Theme.targets[:translations], name: "en_US", value: "") }
    let!(:ca3) { ThemeField.create!(theme: theme3, target_id: Theme.targets[:translations], name: "ca", value: "") }
    let!(:en3) { ThemeField.create!(theme: theme3, target_id: Theme.targets[:translations], name: "en_US", value: "") }

    describe "scopes" do
      it "filter_locale_fields returns results in the correct order" do
        expect(ThemeField.find_by_theme_ids([theme3.id, theme.id, theme2.id])
          .filter_locale_fields(
           ["en_US", "fr"]
        )).to eq([en3, en1, fr1, en2, fr2])
      end

      it "find_first_locale_fields returns only the first locale for each theme" do
        expect(ThemeField.find_first_locale_fields(
          [theme3.id, theme.id, theme2.id], ["ca", "en_US", "fr"]
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
          en_US: { somestring1: "helloworld", group: { key1: "enval1" } }
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
          en_US: { somestring1: "helloworld", group: { key1: "overriddentest1" } }
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
        theme_field.ensure_baked!
        javascript_cache = theme_field.javascript_cache
        expect(javascript_cache.content).to include("inline discourse plugin")
        expect(javascript_cache.content).to include("theme_translations.#{theme.id}.")
      end
    end
  end

end
