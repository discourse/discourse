# encoding: utf-8
# frozen_string_literal: true

RSpec.describe ThemeField do
  fab!(:theme)

  before do
    SvgSprite.clear_plugin_svg_sprite_cache!
    ThemeJavascriptCompiler.disable_terser!
  end

  after { ThemeJavascriptCompiler.enable_terser! }

  describe "scope: find_by_theme_ids" do
    it "returns result in the specified order" do
      theme2 = Fabricate(:theme)
      theme3 = Fabricate(:theme)

      (0..1).each do |num|
        ThemeField.create!(theme: theme, target_id: num, name: "header", value: "<a>html</a>")
        ThemeField.create!(theme: theme2, target_id: num, name: "header", value: "<a>html</a>")
        ThemeField.create!(theme: theme3, target_id: num, name: "header", value: "<a>html</a>")
      end

      expect(ThemeField.find_by_theme_ids([theme3.id, theme.id, theme2.id]).pluck(:theme_id)).to eq(
        [theme3.id, theme3.id, theme.id, theme.id, theme2.id, theme2.id],
      )
    end
  end

  it "does not insert a script tag when there are no inline script" do
    theme_field =
      ThemeField.create!(theme_id: -1, target_id: 0, name: "body_tag", value: "<div>new div</div>")
    theme_field.ensure_baked!
    expect(theme_field.value_baked).to_not include("<script")
  end

  it "adds an error when optimized image links are included" do
    theme_field = theme.set_field(target: :common, name: :body_tag, value: <<~HTML)
      <img src="http://mysite.invalid/uploads/default/optimized/1X/6d749a141f513f88f167e750e528515002043da1_2_1282x1000.png"/>
    HTML
    theme.save!
    expect(theme_field.reload.error).to include(I18n.t("themes.errors.optimized_link"))

    theme_field = theme.set_field(target: :common, name: :scss, value: <<~SCSS)
      body {
        background: url(http://mysite.invalid/uploads/default/optimized/1X/6d749a141f513f88f167e750e528515002043da1_2_1282x1000.png);
      }
    SCSS
    theme.save!
    expect(theme_field.reload.error).to include(I18n.t("themes.errors.optimized_link"))

    theme_field.update(value: <<~SCSS)
      body {
        background: url(http://notdiscourse.invalid/optimized/my_image.png);
      }
    SCSS
    theme_field.ensure_baked!
    expect(theme_field.error).to eq(nil)
  end

  it "extracts inline javascript to an external file" do
    html = <<~HTML
      <script type="text/discourse-plugin" version="0.8">
        console.log("inline discourse plugin");
      </script>
      <script type="text/template" data-template="custom-template">
        <div>custom script type</div>
      </script>
      <script>
        console.log("inline raw script");
      </script>
      <script type="texT/jAvasCripT">
        console.log("text/javascript");
      </script>
      <script type="application/javascript">
        console.log("application/javascript");
      </script>
      <script src="/external-script.js"></script>
    HTML

    theme_field = ThemeField.create!(theme_id: -1, target_id: 0, name: "header", value: html)
    theme_field.ensure_baked!

    baked_doc = Nokogiri::HTML5.fragment(theme_field.value_baked)

    simple_extracted_scripts = baked_doc.css("script[src^='/theme-javascripts/']")
    expect(simple_extracted_scripts.length).to eq(3)

    extracted_module_preloads =
      baked_doc.css("link[rel=modulepreload][href^='/theme-javascripts/']")
    expect(extracted_module_preloads.length).to eq(1)

    expect(theme_field.javascript_cache.content).to include("inline discourse plugin")

    raw_js_cache_contents = theme_field.raw_javascript_caches.map(&:content)
    expect(raw_js_cache_contents).to contain_exactly(
      'console.log("inline raw script");',
      'console.log("text/javascript");',
      'console.log("application/javascript");',
    )

    expect(baked_doc.css("script[type='text/template']").length).to eq(1)
  end

  it "correctly logs errors for transpiled js" do
    html = <<HTML
<script type="text/discourse-plugin" version="0.8">
   badJavaScript(;
</script>
HTML

    field = ThemeField.create!(theme_id: -1, target_id: 0, name: "header", value: html)
    field.ensure_baked!
    expect(field.value_baked).to include(
      "<link rel=\"modulepreload\" href=\"#{field.javascript_cache.url}\" data-theme-id=\"-1\" nonce=\"#{ThemeField::CSP_NONCE_PLACEHOLDER}\">",
    )
    expect(field.javascript_cache.content).to include("[THEME -1 'Foundation'] Compile error")

    field.update!(value: "")
    field.ensure_baked!
  end

  it "correctly extracts and generates errors for raw transpiled js" do
    html = <<~HTML
      <script>
        badJavaScript(;
      </script>
    HTML

    field = ThemeField.create!(theme_id: -1, target_id: 0, name: "header", value: html)
    field.ensure_baked!

    expect(field.error).not_to eq(nil)
    expect(field.value_baked).to include(
      "<script defer=\"\" src=\"#{field.raw_javascript_caches[0].url}\" data-theme-id=\"-1\" nonce=\"#{ThemeField::CSP_NONCE_PLACEHOLDER}\"></script>",
    )
    expect(field.raw_javascript_caches[0].content).to include(
      "[THEME -1 'Foundation'] Compile error",
    )

    field.update!(value: "")
    field.ensure_baked!
    expect(field.error).to eq(nil)
  end

  it "allows us to use theme settings in handlebars templates" do
    html = <<HTML
<script type='text/x-handlebars' data-template-name='my-template'>
    <div class="testing-div">{{themeSettings.string_setting}}</div>
</script>
HTML

    ThemeField.create!(
      theme_id: -1,
      target_id: 3,
      name: "yaml",
      value: "string_setting: \"test text \\\" 123!\"",
    ).ensure_baked!
    theme_field = ThemeField.create!(theme_id: -1, target_id: 0, name: "head_tag", value: html)
    theme_field.ensure_baked!
    javascript_cache = theme_field.javascript_cache

    expect(theme_field.value_baked).to include(
      "<link rel=\"modulepreload\" href=\"#{javascript_cache.url}\" data-theme-id=\"-1\" nonce=\"#{ThemeField::CSP_NONCE_PLACEHOLDER}\">",
    )
    expect(javascript_cache.content).to include("testing-div")
    expect(javascript_cache.content).to include("string_setting")
    expect(javascript_cache.content).to include("test text \\\" 123!")
    expect(javascript_cache.content).to include(
      'themeCompatModules["discourse/templates/my-template"]',
    )
  end

  it "correctly generates errors for transpiled css" do
    css = "body {"
    field = theme.set_field(target: :common, name: :scss, value: css)
    theme.save!
    expect(field.reload.error).to include('Error: expected "}"')

    theme.set_field(target: :common, name: :scss, value: <<~SCSS)
      body {
        color: unquote("https://example.com/this-is-a-mistake");
      }
    SCSS
    theme.save!
    expect(field.reload.error).to include("Missed semicolon")

    theme.set_field(target: :common, name: :scss, value: "@import 'missingfile';")
    theme.save!
    expect(field.reload.error).to include("Error: Can't find stylesheet to import.")

    theme.set_field(target: :common, name: :scss, value: "body {color: blue};")
    theme.save!
    expect(field.reload.error).to eq(nil)
  end

  it "allows importing scss files" do
    main_field =
      theme.set_field(
        target: :common,
        name: :scss,
        value: ".class1{color: red}\n@import 'rootfile1';\n@import 'rootfile3';",
      )
    theme.set_field(
      target: :extra_scss,
      name: "rootfile1",
      value: ".class2{color:green}\n@import 'foldername/subfile1';",
    )
    theme.set_field(target: :extra_scss, name: "rootfile2", value: ".class3{color:green} ")
    theme.set_field(
      target: :extra_scss,
      name: "foldername/subfile1",
      value: ".class4{color:yellow}\n@import 'subfile2';",
    )
    theme.set_field(
      target: :extra_scss,
      name: "foldername/subfile2",
      value: ".class5{color:yellow}\n@import '../rootfile2';",
    )
    theme.set_field(target: :extra_scss, name: "rootfile3", value: ".class6{color:green} ")

    theme.save!
    result = main_field.compile_scss[0]

    expect(result).to include(".class1")
    expect(result).to include(".class2")
    expect(result).to include(".class3")
    expect(result).to include(".class4")
    expect(result).to include(".class5")
    expect(result).to include(".class6")
  end

  it "correctly handles extra JS fields" do
    js_field =
      theme.set_field(
        target: :extra_js,
        name: "discourse/controllers/discovery.js.es6",
        value: "import 'discourse/lib/ajax'; console.log('hello from .js.es6');",
      )
    _js_2_field =
      theme.set_field(
        target: :extra_js,
        name: "discourse/controllers/discovery-2.js",
        value: "import 'discourse/lib/ajax'; console.log('hello from .js');",
      )
    hbs_field =
      theme.set_field(
        target: :extra_js,
        name: "discourse/templates/discovery.hbs",
        value: "{{hello-world}}",
      )
    hbr_field =
      theme.set_field(
        target: :extra_js,
        name: "discourse/templates/other_discovery.hbr",
        value: "{{hello-world}}",
      )
    unknown_field =
      theme.set_field(
        target: :extra_js,
        name: "discourse/controllers/discovery.blah",
        value: "this wont work",
      )
    theme.save!

    js_field.reload
    expect(js_field.value_baked).to eq("baked")
    expect(js_field.value_baked).to eq("baked")
    expect(js_field.value_baked).to eq("baked")

    # All together
    expect(theme.javascript_cache.content).to include(
      'themeCompatModules["discourse/templates/discovery"]',
    )
    expect(theme.javascript_cache.content).to include(
      'themeCompatModules["discourse/controllers/discovery"]',
    )
    expect(theme.javascript_cache.content).to include(
      'themeCompatModules["discourse/controllers/discovery-2"]',
    )
    expect(theme.javascript_cache.content).to include("registerSettings(")
    expect(theme.javascript_cache.content).to include(
      "[THEME #{theme.id}] Unsupported file type: discourse/controllers/discovery.blah",
    )
    expect(theme.javascript_cache.content).to include(
      "[THEME #{theme.id}] Unsupported file type: discourse/templates/other_discovery.hbr",
    )

    expect(theme.javascript_cache.source_map).not_to eq(nil)
    map = JSON.parse(theme.javascript_cache.source_map)

    expect(map["sources"]).to contain_exactly(
      "theme-#{theme.id}/discourse/controllers/discovery-2.js",
      "theme-#{theme.id}/discourse/controllers/discovery.js",
      "theme-#{theme.id}/discourse/templates/discovery.hbs",
      "theme-#{theme.id}/virtual:main",
      "theme-#{theme.id}/virtual:theme",
      "theme-#{theme.id}/virtual:init-settings",
    )
    expect(map["sourcesContent"].length).to eq(6)
  end

  def create_upload_theme_field!(name)
    ThemeField
      .create!(
        theme_id: -1,
        target_id: 0,
        value: "",
        type_id: ThemeField.types[:theme_upload_var],
        name: name,
      )
      .tap { |tf| tf.ensure_baked! }
  end

  it "ensures we don't use invalid SCSS variable names" do
    expect { create_upload_theme_field!("42") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { create_upload_theme_field!("a42") }.not_to raise_error
  end

  def get_fixture(type)
    File.read("#{Rails.root}/spec/fixtures/theme_settings/#{type}_settings.yaml")
  end

  def create_yaml_field(value)
    field =
      ThemeField.create!(
        theme_id: -1,
        target_id: Theme.targets[:settings],
        name: "yaml",
        value: value,
      )
    field.ensure_baked!
    field
  end

  let(:key) { "themes.settings_errors" }

  it "forces re-transpilation of theme JS when settings YAML changes" do
    settings_field =
      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:settings],
        name: "yaml",
        value: "setting: 5",
      )

    html = <<~HTML
      <script type="text/discourse-plugin" version="0.8">
        alert(settings.setting);
      </script>
    HTML

    js_field =
      ThemeField.create!(
        theme: theme,
        target_id: ThemeField.types[:html],
        name: "header",
        value: html,
      )
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
    expect(field.error).to include(
      I18n.t("#{key}.default_not_match_type", name: "no_match_setting"),
    )
  end

  it "generates errors when no default value is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(
      I18n.t("#{key}.default_value_missing", name: "no_default_setting"),
    )
  end

  it "generates errors when invalid type is passed" do
    field = create_yaml_field(get_fixture("invalid"))
    expect(field.error).to include(
      I18n.t("#{key}.data_type_inclusion", name: "invalid_type_setting"),
    )
  end

  it "generates errors when default value is not within allowed range" do
    field = create_yaml_field(get_fixture("invalid"))

    expect(field.error).to include(
      I18n.t(
        "#{key}.default_value_not_valid",
        name: "default_out_of_range",
        error_messages: [I18n.t("#{key}.number_value_not_valid_min_max", min: 1, max: 20)].join(
          " ",
        ),
      ),
    )

    expect(field.error).to include(
      I18n.t(
        "#{key}.default_value_not_valid",
        name: "string_default_out_of_range",
        error_messages: [I18n.t("#{key}.string_value_not_valid_min", min: 20)].join(" "),
      ),
    )
  end

  it "generates the right errors when setting of type objects have default values which does not matches the schema" do
    field = create_yaml_field(get_fixture("invalid"))

    expect(field.error).to include(
      "Setting `invalid_default_objects_setting` default value isn't valid. The property at JSON Pointer '/0/required_string' must be present. The property at JSON Pointer '/1/min_5_chars_string' must be at least 5 characters long. The property at JSON Pointer '/1/children/0/required_integer' must be present.",
    )
  end

  it "works correctly when valid yaml is provided" do
    field = create_yaml_field(get_fixture("valid"))
    expect(field.error).to be_nil
  end

  describe "locale fields" do
    let!(:theme) { Fabricate(:theme) }
    let!(:theme2) { Fabricate(:theme) }
    let!(:theme3) { Fabricate(:theme) }

    let!(:en1) do
      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:translations],
        name: "en",
        value: {
          en: {
            somestring1: "helloworld",
            group: {
              key1: "enval1",
            },
          },
        }.deep_stringify_keys.to_yaml,
      )
    end
    let!(:fr1) do
      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:translations],
        name: "fr",
        value: {
          fr: {
            somestring1: "bonjourworld",
            group: {
              key2: "frval2",
            },
          },
        }.deep_stringify_keys.to_yaml,
      )
    end
    let!(:fr2) do
      ThemeField.create!(
        theme: theme2,
        target_id: Theme.targets[:translations],
        name: "fr",
        value: "",
      )
    end
    let!(:en2) do
      ThemeField.create!(
        theme: theme2,
        target_id: Theme.targets[:translations],
        name: "en",
        value: "",
      )
    end
    let!(:ca3) do
      ThemeField.create!(
        theme: theme3,
        target_id: Theme.targets[:translations],
        name: "ca",
        value: "",
      )
    end
    let!(:en3) do
      ThemeField.create!(
        theme: theme3,
        target_id: Theme.targets[:translations],
        name: "en",
        value: "",
      )
    end

    describe "scopes" do
      it "filter_locale_fields returns results in the correct order" do
        expect(
          ThemeField.find_by_theme_ids([theme3.id, theme.id, theme2.id]).filter_locale_fields(
            %w[en fr],
          ),
        ).to eq([en3, en1, fr1, en2, fr2])
      end

      it "find_first_locale_fields returns only the first locale for each theme" do
        expect(
          ThemeField.find_first_locale_fields([theme3.id, theme.id, theme2.id], %w[ca en fr]),
        ).to eq([ca3, en1, en2])
      end
    end

    describe "#raw_translation_data" do
      it "errors if the top level key is incorrect" do
        fr1.update(value: { wrongkey: { somestring1: "bonjourworld" } }.deep_stringify_keys.to_yaml)
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if there are multiple top level keys" do
        fr1.update(
          value: {
            fr: {
              somestring1: "bonjourworld",
            },
            otherkey: "hello",
          }.deep_stringify_keys.to_yaml,
        )
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if YAML includes arrays" do
        fr1.update(value: { fr: %w[val1 val2] }.deep_stringify_keys.to_yaml)
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "errors if YAML has invalid syntax" do
        fr1.update(value: "fr: 'valuewithoutclosequote")
        expect { fr1.raw_translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "works when locale file doesn't contain translations" do
        fr1.update(value: "fr:")
        expect(fr1.translation_data).to eq(
          fr: {
          },
          en: {
            somestring1: "helloworld",
            group: {
              key1: "enval1",
            },
          },
        )
      end
    end

    describe "#translation_data" do
      it "loads correctly" do
        expect(fr1.translation_data).to eq(
          fr: {
            somestring1: "bonjourworld",
            group: {
              key2: "frval2",
            },
          },
          en: {
            somestring1: "helloworld",
            group: {
              key1: "enval1",
            },
          },
        )
      end

      it "raises errors for the current locale" do
        fr1.update(value: { wrongkey: "hello" }.deep_stringify_keys.to_yaml)
        expect { fr1.translation_data }.to raise_error(ThemeTranslationParser::InvalidYaml)
      end

      it "doesn't raise errors for the fallback locale" do
        en1.update(value: { wrongkey: "hello" }.deep_stringify_keys.to_yaml)
        expect(fr1.translation_data).to eq(
          fr: {
            somestring1: "bonjourworld",
            group: {
              key2: "frval2",
            },
          },
        )
      end

      it "merges any overrides" do
        # Overrides in the current locale (so in tests that will be english)
        theme.update_translation("group.key1", "overriddentest1")
        theme.reload
        expect(fr1.translation_data).to eq(
          fr: {
            somestring1: "bonjourworld",
            group: {
              key2: "frval2",
            },
          },
          en: {
            somestring1: "helloworld",
            group: {
              key1: "overriddentest1",
            },
          },
        )
      end
    end

    describe "javascript cache" do
      it "is generated correctly" do
        fr1.ensure_baked!
        expect(fr1.value_baked).to include(
          "<script type=\"module\" src=\"#{fr1.javascript_cache.url}\" data-theme-id=\"#{fr1.theme_id}\" nonce=\"#{ThemeField::CSP_NONCE_PLACEHOLDER}\"></script>",
        )
        expect(fr1.javascript_cache.content).to include("bonjourworld")
        expect(fr1.javascript_cache.content).to include("helloworld")
        expect(fr1.javascript_cache.content).to include("enval1")
      end

      it "is recreated when data changes" do
        t = Fabricate(:theme)
        t.set_field(
          target: "translations",
          name: "fr",
          value: { fr: { mykey: "initial value" } }.deep_stringify_keys.to_yaml,
        )
        t.save!

        field = t.theme_fields.find_by(target_id: Theme.targets[:translations], name: "fr")
        expect(field.javascript_cache.content).to include("initial value")

        t.set_field(
          target: "translations",
          name: "fr",
          value: { fr: { mykey: "new value" } }.deep_stringify_keys.to_yaml,
        )
        t.save!

        field = t.theme_fields.find_by(target_id: Theme.targets[:translations], name: "fr")
        expect(field.javascript_cache.reload.content).to include("new value")
      end

      it "is recreated when fallback data changes" do
        t = Fabricate(:theme)
        t.set_field(
          target: "translations",
          name: "fr",
          value: { fr: {} }.deep_stringify_keys.to_yaml,
        )
        t.set_field(
          target: "translations",
          name: "en",
          value: { en: { myotherkey: "initial value" } }.deep_stringify_keys.to_yaml,
        )
        t.save!

        field = t.theme_fields.find_by(target_id: Theme.targets[:translations], name: "fr")
        expect(field.javascript_cache.content).to include("initial value")

        t.set_field(
          target: "translations",
          name: "en",
          value: { en: { myotherkey: "new value" } }.deep_stringify_keys.to_yaml,
        )
        t.save!

        field = t.theme_fields.find_by(target_id: Theme.targets[:translations], name: "fr")
        expect(field.javascript_cache.reload.content).to include("new value")
      end
    end

    describe "prefix injection" do
      it "injects into JS" do
        html = <<~HTML
          <script type="text/discourse-plugin" version="0.8">
            console.log("inline discourse plugin", themePrefix("foo"));
          </script>
        HTML

        theme_field =
          ThemeField.create!(theme_id: theme.id, target_id: 0, name: "head_tag", value: html)
        theme_field.ensure_baked!
        javascript_cache = theme_field.javascript_cache
        expect(javascript_cache.content).to include("inline discourse plugin")
        expect(javascript_cache.content).to include("theme_translations.#{theme.id}.")
      end
    end
  end

  describe "SVG sprite theme fields" do
    let :svg_content do
      "<svg><symbol id='test'></symbol></svg>"
    end

    let :upload_file do
      tmp = Tempfile.new("test.svg")
      File.write(tmp.path, svg_content)
      tmp
    end

    after { upload_file.unlink }

    let(:upload) do
      UploadCreator.new(upload_file, "test.svg", for_theme: true).create_for(
        Discourse::SYSTEM_USER_ID,
      )
    end

    let(:theme) { Fabricate(:theme) }
    let(:theme_field) do
      ThemeField.create!(
        theme: theme,
        target_id: 0,
        name: SvgSprite.theme_sprite_variable_name,
        upload: upload,
        value: "",
        value_baked: "baked",
        type_id: ThemeField.types[:theme_upload_var],
      )
    end

    it "is rebaked when upload changes" do
      fname = "custom-theme-icon-sprite.svg"
      sprite = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)
      theme_field.update(upload: sprite)
      expect(theme_field.value_baked).to eq(nil)
    end

    it "clears SVG sprite cache when upload is deleted" do
      theme_field
      expect(SvgSprite.custom_svgs(theme.id).size).to eq(1)

      theme_field.destroy!
      expect(SvgSprite.custom_svgs(theme.id).size).to eq(0)
    end

    it "crashes gracefully when svg is invalid" do
      FileStore::LocalStore.any_instance.stubs(:path_for).returns(nil)
      expect(theme_field.validate_svg_sprite_xml).to match("Error with icons-sprite")
    end

    it "raises an error when sprite is too big" do
      fname = "theme-icon-sprite.svg"
      symbols = ""

      3500.times do |i|
        id = "icon-id-#{i}"
        path =
          "M#{rand(1..100)} 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 .008z"
        symbols += "<symbol id='#{id}' viewBox='0 0 100 100'><path d='#{path}'/></symbol>\n"
      end

      contents =
        "<?xml version='1.0' encoding='UTF-8'?><svg><symbol id='customthemeicon' viewBox='0 0 100 100'><path d='M0 0h1ssss00v100H0z'/></symbol>#{symbols}</svg>"

      sprite =
        UploadCreator.new(file_from_contents(contents, fname), fname, for_theme: true).create_for(
          -1,
        )

      theme_field.update(upload: sprite)

      expect(theme_field.validate_svg_sprite_xml).to match("Error with icons-sprite")
    end
  end

  describe "local js assets" do
    let :js_content do
      "// not transpiled; console.log('hello world');"
    end

    let :upload_file do
      tmp = Tempfile.new(%w[jsfile .js])
      File.write(tmp.path, js_content)
      tmp
    end

    after { upload_file.unlink }

    it "correctly handles local JS asset caching" do
      # todo - make this a system spec
      upload =
        UploadCreator.new(upload_file, "test.js", for_theme: true).create_for(
          Discourse::SYSTEM_USER_ID,
        )

      js_field =
        theme.set_field(
          target: :common,
          type_id: ThemeField.types[:theme_upload_var],
          name: "test_js",
          upload_id: upload.id,
        )

      common_field =
        theme.set_field(
          target: :common,
          name: "head_tag",
          value: "<script type='text/discourse-plugin' version='0.1'>let c = 'd';</script>",
          type: :html,
        )

      theme.set_field(target: :settings, type: :yaml, name: "yaml", value: "hello: world")

      theme.set_field(
        target: :extra_js,
        name: "discourse/controllers/discovery.js.es6",
        value: "import 'discourse/lib/ajax'; console.log('hello from .js.es6');",
      )

      theme.save!

      # a bit fragile, but at least we test it properly
      [
        theme.reload.javascript_cache.content,
        common_field.reload.javascript_cache.content,
      ].each do |js|
        expected_local_js_cache_url = js_field.javascript_cache.local_url
        expect(expected_local_js_cache_url).to start_with("/theme-javascripts/")
        expect(js).to include(<<~JS)
          registerSettings(#{theme.id}, {
            "hello": "world",
            "theme_uploads": {
              "test_js": "#{js_field.upload.url}"
            },
            "theme_uploads_local": {
              "test_js": "#{js_field.javascript_cache.local_url}"
            }
          });
        JS
      end

      # this is important, we do not want local_js_urls to leak into scss
      expect(theme.scss_variables).to include("$hello: unquote(\"world\");")
      expect(theme.scss_variables).to include("$test_js: unquote(\"#{upload.url}\");")

      expect(theme.scss_variables).not_to include("theme_uploads")
    end
  end

  describe "migration JavaScript field" do
    it "must match a specific format for filename" do
      field = Fabricate(:migration_theme_field, theme: theme)
      field.name = "12-some-name"

      expect(field.valid?).to eq(false)
      expect(field.errors.full_messages).to contain_exactly(
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "12-some-name"),
      )

      field.name = "00012-some-name"

      expect(field.valid?).to eq(false)
      expect(field.errors.full_messages).to contain_exactly(
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "00012-some-name"),
      )

      field.name = "0012some-name"

      expect(field.valid?).to eq(false)
      expect(field.errors.full_messages).to contain_exactly(
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "0012some-name"),
      )

      field.name = "0012"

      expect(field.valid?).to eq(false)
      expect(field.errors.full_messages).to contain_exactly(
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "0012"),
      )

      field.name = "0012-something"

      expect(field.valid?).to eq(true)
    end

    it "doesn't allow weird characters in the name" do
      field = Fabricate(:migration_theme_field, theme: theme)
      field.name = "0012-ëèard"

      expect(field.valid?).to eq(false)
      expect(field.errors.full_messages).to contain_exactly(
        I18n.t("themes.import_error.migrations.invalid_filename", filename: "0012-ëèard"),
      )
    end

    it "imposes a limit on the name part in the filename" do
      stub_const(ThemeField, "MIGRATION_NAME_PART_MAX_LENGTH", 10) do
        field = Fabricate(:migration_theme_field, theme: theme)
        field.name = "0012-#{"a" * 11}"

        expect(field.valid?).to eq(false)
        expect(field.errors.full_messages).to contain_exactly(
          I18n.t("themes.import_error.migrations.name_too_long", count: 10),
        )

        field.name = "0012-#{"a" * 10}"

        expect(field.valid?).to eq(true)
      end
    end
  end
end
