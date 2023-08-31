# frozen_string_literal: true

RSpec.describe Theme do
  after { Theme.clear_cache! }

  before { ThemeJavascriptCompiler.disable_terser! }
  after { ThemeJavascriptCompiler.enable_terser! }

  fab! :user do
    Fabricate(:user)
  end

  let(:guardian) { Guardian.new(user) }

  let(:theme) { Fabricate(:theme, user: user) }
  let(:child) { Fabricate(:theme, user: user, component: true) }

  it "can properly clean up color schemes" do
    scheme = ColorScheme.create!(theme_id: theme.id, name: "test")
    scheme2 = ColorScheme.create!(theme_id: theme.id, name: "test2")

    Fabricate(:theme, color_scheme_id: scheme2.id)

    theme.destroy!
    scheme2.reload

    expect(scheme2).not_to eq(nil)
    expect(scheme2.theme_id).to eq(nil)
    expect(ColorScheme.find_by(id: scheme.id)).to eq(nil)
  end

  it "can support child themes" do
    child.set_field(target: :common, name: "header", value: "World")
    child.set_field(target: :desktop, name: "header", value: "Desktop")
    child.set_field(target: :mobile, name: "header", value: "Mobile")

    child.save!

    expect(Theme.lookup_field(child.id, :desktop, "header")).to eq("World\nDesktop")
    expect(Theme.lookup_field(child.id, "mobile", :header)).to eq("World\nMobile")

    child.set_field(target: :common, name: "header", value: "Worldie")
    child.save!

    expect(Theme.lookup_field(child.id, :mobile, :header)).to eq("Worldie\nMobile")

    parent = Fabricate(:theme, user: user)

    parent.set_field(target: :common, name: "header", value: "Common Parent")
    parent.set_field(target: :mobile, name: "header", value: "Mobile Parent")

    parent.save!

    parent.add_relative_theme!(:child, child)

    expect(Theme.lookup_field(parent.id, :mobile, "header")).to eq(
      "Common Parent\nMobile Parent\nWorldie\nMobile",
    )
  end

  it "can support parent themes" do
    child.add_relative_theme!(:parent, theme)
    expect(child.parent_themes).to eq([theme])
  end

  it "can automatically disable for mismatching version" do
    theme.create_remote_theme!(remote_url: "", minimum_discourse_version: "99.99.99")
    theme.save!

    expect(Theme.transform_ids(theme.id)).to eq([])
  end

  it "#transform_ids works with nil values" do
    # Used in safe mode
    expect(Theme.transform_ids(nil)).to eq([])
  end

  it "#transform_ids filters out disabled components" do
    theme.add_relative_theme!(:child, child)
    expect(Theme.transform_ids(theme.id)).to eq([theme.id, child.id])
    child.update!(enabled: false)
    expect(Theme.transform_ids(theme.id)).to eq([theme.id])
  end

  it "doesn't allow multi-level theme components" do
    grandchild = Fabricate(:theme, user: user)
    grandparent = Fabricate(:theme, user: user)

    expect do child.add_relative_theme!(:child, grandchild) end.to raise_error(
      Discourse::InvalidParameters,
      I18n.t("themes.errors.no_multilevels_components"),
    )

    expect do grandparent.add_relative_theme!(:child, theme) end.to raise_error(
      Discourse::InvalidParameters,
      I18n.t("themes.errors.no_multilevels_components"),
    )
  end

  it "doesn't allow a child to be user selectable" do
    child.update(user_selectable: true)
    expect(child.errors.full_messages).to contain_exactly(
      I18n.t("themes.errors.component_no_user_selectable"),
    )
  end

  it "doesn't allow a child to be set as the default theme" do
    expect do child.set_default! end.to raise_error(
      Discourse::InvalidParameters,
      I18n.t("themes.errors.component_no_default"),
    )
  end

  it "doesn't allow a component to have color scheme" do
    scheme = ColorScheme.create!(name: "test")
    child.update(color_scheme: scheme)
    expect(child.errors.full_messages).to contain_exactly(
      I18n.t("themes.errors.component_no_color_scheme"),
    )
  end

  it "should correct bad html in body_tag_baked and head_tag_baked" do
    theme.set_field(target: :common, name: "head_tag", value: "<b>I am bold")
    theme.save!

    expect(Theme.lookup_field(theme.id, :desktop, "head_tag")).to eq("<b>I am bold</b>")
  end

  it "should precompile fragments in body and head tags" do
    with_template = <<HTML
    <script type='text/x-handlebars' name='template'>
      {{hello}}
    </script>
    <script type='text/x-handlebars' data-template-name='raw_template.raw'>
      {{hello}}
    </script>
HTML
    theme.set_field(target: :common, name: "header", value: with_template)
    theme.save!

    field = theme.theme_fields.find_by(target_id: Theme.targets[:common], name: "header")
    baked = Theme.lookup_field(theme.id, :mobile, "header")

    expect(baked).to include(field.javascript_cache.url)
    expect(field.javascript_cache.content).to include("@ember/template-factory")
    expect(field.javascript_cache.content).to include("raw-handlebars")
  end

  it "can destroy unbaked theme without errors" do
    with_template = <<HTML
    <script type='text/x-handlebars' name='template'>
      {{hello}}
    </script>
    <script type='text/x-handlebars' data-template-name='raw_template.raw'>
      {{hello}}
    </script>
HTML
    theme.set_field(target: :common, name: "header", value: with_template)
    theme.save!

    field = theme.theme_fields.find_by(target_id: Theme.targets[:common], name: "header")
    baked = Theme.lookup_field(theme.id, :mobile, "header")
    ThemeField.where(id: field.id).update_all(compiler_version: 0) # update_all to avoid callbacks

    field.reload.destroy!
  end

  it "should create body_tag_baked on demand if needed" do
    theme.set_field(target: :common, name: :body_tag, value: "<b>test")
    theme.save

    ThemeField.update_all(value_baked: nil)

    expect(Theme.lookup_field(theme.id, :desktop, :body_tag)).to match(%r{<b>test</b>})
  end

  describe "#switch_to_component!" do
    it "correctly converts a theme to component" do
      theme.add_relative_theme!(:child, child)
      scheme = ColorScheme.create!(name: "test")
      theme.update!(color_scheme_id: scheme.id, user_selectable: true)
      theme.set_default!

      theme.switch_to_component!
      theme.reload

      expect(theme.component).to eq(true)
      expect(theme.user_selectable).to eq(false)
      expect(theme.default?).to eq(false)
      expect(theme.color_scheme_id).to eq(nil)
      expect(ChildTheme.where(parent_theme: theme).exists?).to eq(false)
    end
  end

  describe "#switch_to_theme!" do
    it "correctly converts a component to theme" do
      theme.add_relative_theme!(:child, child)

      child.switch_to_theme!
      theme.reload
      child.reload

      expect(child.component).to eq(false)
      expect(ChildTheme.where(child_theme: child).exists?).to eq(false)
    end
  end

  describe ".transform_ids" do
    let!(:orphan1) { Fabricate(:theme, component: true) }
    let!(:child) { Fabricate(:theme, component: true) }
    let!(:child2) { Fabricate(:theme, component: true) }
    let!(:orphan2) { Fabricate(:theme, component: true) }
    let!(:orphan3) { Fabricate(:theme, component: true) }
    let!(:orphan4) { Fabricate(:theme, component: true) }

    before do
      theme.add_relative_theme!(:child, child)
      theme.add_relative_theme!(:child, child2)
    end

    it "returns an empty array if no ids are passed" do
      expect(Theme.transform_ids(nil)).to eq([])
    end

    it "adds the child themes of the parent" do
      sorted = [child.id, child2.id].sort

      expect(Theme.transform_ids(theme.id)).to eq([theme.id, *sorted])
    end
  end

  describe "plugin api" do
    def transpile(html)
      f =
        ThemeField.create!(
          target_id: Theme.targets[:mobile],
          theme_id: 1,
          name: "after_header",
          value: html,
        )
      f.ensure_baked!
      [f.value_baked, f.javascript_cache, f]
    end

    it "transpiles ES6 code" do
      html = <<HTML
        <script type='text/discourse-plugin' version='0.1'>
          const x = 1;
        </script>
HTML

      baked, javascript_cache, field = transpile(html)
      expect(baked).to include(javascript_cache.url)

      expect(javascript_cache.content).to include("if ('define' in window) {")
      expect(javascript_cache.content).to include(
        "define(\"discourse/theme-#{field.theme_id}/initializers/theme-field-#{field.id}-mobile-html-script-1\"",
      )
      expect(javascript_cache.content).to include(
        "settings = require(\"discourse/lib/theme-settings-store\").getObjectForTheme(#{field.theme_id});",
      )
      expect(javascript_cache.content).to include(
        "name: \"theme-field-#{field.id}-mobile-html-script-1\",",
      )
      expect(javascript_cache.content).to include("after: \"inject-objects\",")
      expect(javascript_cache.content).to include("(0, _pluginApi.withPluginApi)(\"0.1\", api =>")
      expect(javascript_cache.content).to include("const x = 1;")
    end
  end

  describe "theme upload vars" do
    let :image do
      file_from_fixtures("logo.png")
    end

    it "can handle uploads based of ThemeField" do
      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      theme.set_field(target: :common, name: :logo, upload_id: upload.id, type: :theme_upload_var)
      theme.set_field(target: :common, name: :scss, value: "body {background-image: url($logo)}")
      theme.save!

      # make sure we do not nuke it
      freeze_time (SiteSetting.clean_orphan_uploads_grace_period_hours + 1).hours.from_now
      Jobs::CleanUpUploads.new.execute(nil)

      expect(Upload.where(id: upload.id)).to be_exists

      # no error for theme field
      theme.reload
      expect(theme.theme_fields.find_by(name: :scss).error).to eq(nil)

      manager = Stylesheet::Manager.new(theme_id: theme.id)

      scss, _map =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).compile(force: true)

      expect(scss).to include(upload.url)
    end
  end

  describe "theme settings" do
    it "allows values to be used in scss" do
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: "background_color: red\nfont_size: 25px",
      )
      theme.set_field(
        target: :common,
        name: :scss,
        value: "body {background-color: $background_color; font-size: $font-size}",
      )
      theme.save!

      manager = Stylesheet::Manager.new(theme_id: theme.id)

      scss, _map =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).compile(force: true)

      expect(scss).to include("background-color:red")
      expect(scss).to include("font-size:25px")

      setting = theme.settings.find { |s| s.name == :font_size }
      setting.value = "30px"
      theme.save!

      scss, _map =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).compile(force: true)

      expect(scss).to include("font-size:30px")

      # Escapes correctly. If not, compiling this would throw an exception
      setting.value = <<~CSS
          \#{$fakeinterpolatedvariable}
          andanothervalue 'withquotes'; margin: 0;
      CSS

      theme.set_field(target: :common, name: :scss, value: "body {font-size: quote($font-size)}")
      theme.save!

      scss, _map =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).compile(force: true)

      expect(scss).to include(
        'font-size:"#{$fakeinterpolatedvariable}\a andanothervalue \'withquotes\'; margin: 0;\a"',
      )
    end

    it "can use a setting straight away after introducing it" do
      theme.set_field(target: :common, name: :scss, value: "body {background-color: red;}")
      theme.save!

      theme.reload
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: "background_color: red\nfont_size: 25px",
      )
      theme.set_field(
        target: :common,
        name: :scss,
        value: "body {background-color: $background_color;}",
      )
      theme.save!

      expect(
        theme.theme_fields.find_by(target_id: Theme.targets[:common], name: "scss").error,
      ).to eq(nil)
    end

    it "allows values to be used in JS" do
      theme.name = 'awesome theme"'
      theme.set_field(target: :settings, name: :yaml, value: "name: bob")
      theme_field =
        theme.set_field(
          target: :common,
          name: :after_header,
          value:
            '<script type="text/discourse-plugin" version="1.0">alert(settings.name); let a = ()=>{};</script>',
        )
      theme.save!

      theme_field.reload
      expect(Theme.lookup_field(theme.id, :desktop, :after_header)).to include(
        theme_field.javascript_cache.url,
      )
      expect(theme_field.javascript_cache.content).to include("if ('require' in window) {")
      expect(theme_field.javascript_cache.content).to include(
        "require(\"discourse/lib/theme-settings-store\").registerSettings(#{theme_field.theme.id}, {\"name\":\"bob\"});",
      )
      expect(theme_field.javascript_cache.content).to include("if ('define' in window) {")
      expect(theme_field.javascript_cache.content).to include(
        "define(\"discourse/theme-#{theme_field.theme.id}/initializers/theme-field-#{theme_field.id}-common-html-script-1\",",
      )
      expect(theme_field.javascript_cache.content).to include(
        "name: \"theme-field-#{theme_field.id}-common-html-script-1\",",
      )
      expect(theme_field.javascript_cache.content).to include("after: \"inject-objects\",")
      expect(theme_field.javascript_cache.content).to include(
        "(0, _pluginApi.withPluginApi)(\"1.0\", api =>",
      )
      expect(theme_field.javascript_cache.content).to include("alert(settings.name)")
      expect(theme_field.javascript_cache.content).to include("let a = () => {}")

      setting = theme.settings.find { |s| s.name == :name }
      setting.value = "bill"
      theme.save!

      theme_field.reload
      expect(theme_field.javascript_cache.content).to include(
        "require(\"discourse/lib/theme-settings-store\").registerSettings(#{theme_field.theme.id}, {\"name\":\"bill\"});",
      )
      expect(Theme.lookup_field(theme.id, :desktop, :after_header)).to include(
        theme_field.javascript_cache.url,
      )
    end

    it "is empty when the settings are invalid" do
      theme.set_field(target: :settings, name: :yaml, value: "nil_setting: ")
      theme.save!

      expect(theme.settings).to be_empty
    end
  end

  it "correctly caches theme ids" do
    Theme.destroy_all

    theme
    theme2 = Fabricate(:theme)

    expect(Theme.theme_ids).to contain_exactly(theme.id, theme2.id)
    expect(Theme.user_theme_ids).to eq([])

    theme.update!(user_selectable: true)

    expect(Theme.user_theme_ids).to contain_exactly(theme.id)

    theme2.update!(user_selectable: true)
    expect(Theme.user_theme_ids).to contain_exactly(theme.id, theme2.id)

    theme.update!(user_selectable: false)
    theme2.update!(user_selectable: false)

    theme.set_default!
    expect(Theme.user_theme_ids).to contain_exactly(theme.id)

    theme.destroy
    theme2.destroy

    expect(Theme.theme_ids).to eq([])
    expect(Theme.user_theme_ids).to eq([])
  end

  it "correctly caches user_themes template" do
    Theme.destroy_all

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"]
    expect(user_themes).to eq([])

    theme = Fabricate(:theme, name: "bob", user_selectable: true)
    theme.save!

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"].map { |t| t["name"] }
    expect(user_themes).to eq(["bob"])

    theme.name = "sam"
    theme.save!

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"].map { |t| t["name"] }
    expect(user_themes).to eq(["sam"])

    Theme.destroy_all

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"]
    expect(user_themes).to eq([])
  end

  def cached_settings(id)
    Theme.find_by(id: id).cached_settings.to_json
  end

  def included_settings(id)
    Theme.find_by(id: id).included_settings.to_json
  end

  it "clears color scheme cache correctly" do
    Theme.destroy_all

    cs =
      Fabricate(
        :color_scheme,
        name: "Fancy",
        color_scheme_colors: [
          Fabricate(:color_scheme_color, name: "header_primary", hex: "F0F0F0"),
          Fabricate(:color_scheme_color, name: "header_background", hex: "1E1E1E"),
          Fabricate(:color_scheme_color, name: "tertiary", hex: "858585"),
        ],
      )

    theme =
      Fabricate(:theme, user_selectable: true, user: Fabricate(:admin), color_scheme_id: cs.id)

    theme.set_default!

    expect(ColorScheme.hex_for_name("header_primary")).to eq("F0F0F0")

    Theme.clear_default!

    expect(ColorScheme.hex_for_name("header_primary")).to eq("333333")
  end

  it "correctly notifies about theme changes" do
    cs1 = Fabricate(:color_scheme)
    cs2 = Fabricate(:color_scheme)

    theme = Fabricate(:theme, user_selectable: true, user: user, color_scheme_id: cs1.id)

    messages = MessageBus.track_publish { theme.save! }.filter { |m| m.channel == "/file-change" }
    expect(messages.count).to eq(1)
    expect(messages.first.data.map { |d| d[:target] }).to contain_exactly(
      :desktop_theme,
      :mobile_theme,
    )

    # With color scheme change:
    messages =
      MessageBus
        .track_publish do
          theme.color_scheme_id = cs2.id
          theme.save!
        end
        .filter { |m| m.channel == "/file-change" }
    expect(messages.count).to eq(1)
    expect(messages.first.data.map { |d| d[:target] }).to contain_exactly(
      :admin,
      :desktop,
      :desktop_theme,
      :mobile,
      :mobile_theme,
    )
  end

  it "includes theme_uploads in settings" do
    Theme.destroy_all

    upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
    theme.set_field(type: :theme_upload_var, target: :common, name: "bob", upload_id: upload.id)
    theme.save!

    json = JSON.parse(cached_settings(theme.id))

    expect(json["theme_uploads"]["bob"]).to eq(upload.url)
  end

  it "does not break on missing uploads in settings" do
    Theme.destroy_all

    upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
    theme.set_field(type: :theme_upload_var, target: :common, name: "bob", upload_id: upload.id)
    theme.save!

    Upload.find(upload.id).destroy
    theme.remove_from_cache!

    json = JSON.parse(cached_settings(theme.id))
    expect(json).to be_empty
  end

  it "uses CDN url for theme_uploads in settings" do
    set_cdn_url("http://cdn.localhost")
    Theme.destroy_all

    upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
    theme.set_field(type: :theme_upload_var, target: :common, name: "bob", upload_id: upload.id)
    theme.save!

    json = JSON.parse(cached_settings(theme.id))

    expect(json["theme_uploads"]["bob"]).to eq("http://cdn.localhost#{upload.url}")
  end

  it "uses CDN url for settings of type upload" do
    set_cdn_url("http://cdn.localhost")
    Theme.destroy_all

    upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      my_upload:
        type: upload
        default: ""
    YAML

    ThemeSetting.create!(
      theme: theme,
      data_type: ThemeSetting.types[:upload],
      value: upload.id.to_s,
      name: "my_upload",
    )
    theme.save!

    json = JSON.parse(cached_settings(theme.id))
    expect(json["my_upload"]).to eq("http://cdn.localhost#{upload.url}")
  end

  describe "convert_settings" do
    it "can migrate a list field to a string field with json schema" do
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: "valid_json_schema_setting:\n  default: \"green,globe\"\n  type: \"list\"",
      )
      theme.save!

      setting = theme.settings.find { |s| s.name == :valid_json_schema_setting }
      setting.value = "red,globe|green,cog|brown,users"
      theme.save!

      expect(setting.type).to eq(ThemeSetting.types[:list])

      yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/valid_settings.yaml")
      theme.set_field(target: :settings, name: "yaml", value: yaml)
      theme.save!

      theme.convert_settings
      setting = theme.settings.find { |s| s.name == :valid_json_schema_setting }

      expect(JSON.parse(setting.value)).to eq(
        JSON.parse(
          '[{"color":"red","icon":"globe"},{"color":"green","icon":"cog"},{"color":"brown","icon":"users"}]',
        ),
      )
      expect(setting.type).to eq(ThemeSetting.types[:string])
    end

    it "does not update setting if data does not validate against json schema" do
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: "valid_json_schema_setting:\n  default: \"green,globe\"\n  type: \"list\"",
      )
      theme.save!

      setting = theme.settings.find { |s| s.name == :valid_json_schema_setting }

      # json_schema_settings.yaml defines only two properties per object and disallows additionalProperties
      setting.value = "red,globe,hey|green,cog,hey|brown,users,nay"
      theme.save!

      yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/valid_settings.yaml")
      theme.set_field(target: :settings, name: "yaml", value: yaml)
      theme.save!

      expect { theme.convert_settings }.to raise_error("Schema validation failed")

      setting.value = "red,globe|green,cog|brown"
      theme.save!

      expect { theme.convert_settings }.not_to raise_error

      setting = theme.settings.find { |s| s.name == :valid_json_schema_setting }
      expect(setting.type).to eq(ThemeSetting.types[:string])
    end

    it "warns when the theme has modified the setting type but data cannot be converted" do
      begin
        @orig_logger = Rails.logger
        Rails.logger = @fake_logger = FakeLogger.new

        theme.set_field(
          target: :settings,
          name: :yaml,
          value: "valid_json_schema_setting:\n  default: \"\"\n  type: \"list\"",
        )
        theme.save!

        setting = theme.settings.find { |s| s.name == :valid_json_schema_setting }
        setting.value = "red,globe"
        theme.save!

        theme.set_field(
          target: :settings,
          name: :yaml,
          value: "valid_json_schema_setting:\n  default: \"\"\n  type: \"string\"",
        )
        theme.save!

        theme.convert_settings
        expect(setting.value).to eq("red,globe")
        expect(@fake_logger.warnings[0]).to include(
          "Theme setting type has changed but cannot be converted.",
        )
      ensure
        Rails.logger = @orig_logger
      end
    end
  end

  describe "theme translations" do
    it "can list working theme_translation_manager objects" do
      en_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
        en:
          theme_metadata:
            description: "Description of my theme"
          group_of_translations:
            translation1: en test1
            translation2: en test2
          base_translation1: en test3
          base_translation2: en test4
      YAML
        )
      fr_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "fr",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
        fr:
          group_of_translations:
            translation2: fr test2
          base_translation2: fr test4
          base_translation3: fr test5
      YAML
        )

      I18n.locale = :fr
      theme.update_translation("group_of_translations.translation1", "overriddentest1")
      translations = theme.translations
      theme.reload

      expect(translations.map(&:key)).to eq(
        %w[
          group_of_translations.translation1
          group_of_translations.translation2
          base_translation1
          base_translation2
          base_translation3
        ],
      )

      expect(translations.map(&:default)).to eq(
        ["en test1", "fr test2", "en test3", "fr test4", "fr test5"],
      )

      expect(translations.map(&:value)).to eq(
        ["overriddentest1", "fr test2", "en test3", "fr test4", "fr test5"],
      )
    end

    it "can list internal theme_translation_manager objects" do
      en_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
        en:
          theme_metadata:
            description: "Description of my theme"
          another_translation: en test4
      YAML
        )
      translations = theme.internal_translations
      expect(translations.map(&:key)).to contain_exactly("theme_metadata.description")
      expect(translations.map(&:value)).to contain_exactly("Description of my theme")
    end

    it "can create a hash of overridden values" do
      en_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
        en:
          group_of_translations:
            translation1: en test1
      YAML
        )

      theme.update_translation("group_of_translations.translation1", "overriddentest1")
      I18n.locale = :fr
      theme.update_translation("group_of_translations.translation1", "overriddentest2")
      theme.reload
      expect(theme.translation_override_hash).to eq(
        "en" => {
          "group_of_translations" => {
            "translation1" => "overriddentest1",
          },
        },
        "fr" => {
          "group_of_translations" => {
            "translation1" => "overriddentest2",
          },
        },
      )
    end

    it "fall back when listing baked field" do
      theme2 = Fabricate(:theme)

      en_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: "",
        )
      fr_translation =
        ThemeField.create!(
          theme_id: theme.id,
          name: "fr",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: "",
        )

      en_translation2 =
        ThemeField.create!(
          theme_id: theme2.id,
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: "",
        )

      expect(
        Theme.list_baked_fields([theme.id, theme2.id], :translations, "fr").map(&:id),
      ).to contain_exactly(fr_translation.id, en_translation2.id)
    end
  end

  describe "automatic recompile" do
    it "must recompile after bumping theme_field version" do
      child.set_field(target: :common, name: "header", value: "World")
      child.set_field(target: :extra_js, name: "test.js.es6", value: "const hello = 'world';")
      child.save!

      first_common_value = Theme.lookup_field(child.id, :desktop, "header")
      first_extra_js_value = Theme.lookup_field(child.id, :extra_js, nil)

      Theme
        .stubs(:compiler_version)
        .returns("SOME_NEW_HASH") do
          second_common_value = Theme.lookup_field(child.id, :desktop, "header")
          second_extra_js_value = Theme.lookup_field(child.id, :extra_js, nil)

          new_common_compiler_version =
            ThemeField.find_by(theme_id: child.id, name: "header").compiler_version
          new_extra_js_compiler_version =
            ThemeField.find_by(theme_id: child.id, name: "test.js.es6").compiler_version

          expect(first_common_value).to eq(second_common_value)
          expect(first_extra_js_value).to eq(second_extra_js_value)

          expect(new_common_compiler_version).to eq("SOME_NEW_HASH")
          expect(new_extra_js_compiler_version).to eq("SOME_NEW_HASH")
        end
    end

    it "recompiles when the hostname changes" do
      theme.set_field(target: :settings, name: :yaml, value: "name: bob")
      theme_field =
        theme.set_field(
          target: :common,
          name: :after_header,
          value: '<script>console.log("hello world");</script>',
        )
      theme.save!

      expect(Theme.lookup_field(theme.id, :common, :after_header)).to include(
        "_ws=#{Discourse.current_hostname}",
      )

      SiteSetting.force_hostname = "someotherhostname.com"
      Theme.clear_cache!

      expect(Theme.lookup_field(theme.id, :common, :after_header)).to include(
        "_ws=someotherhostname.com",
      )
    end
  end

  describe "extra_scss" do
    let(:scss) { "body { background: red}" }
    let(:second_file_scss) { "p { color: blue};" }
    let(:child_scss) { "body { background: green}" }

    let(:theme) do
      Fabricate(:theme).tap do |t|
        t.set_field(target: :extra_scss, name: "my_files/magic", value: scss)
        t.set_field(target: :extra_scss, name: "my_files/magic2", value: second_file_scss)
        t.save!
      end
    end

    let(:child_theme) do
      Fabricate(:theme).tap do |t|
        t.component = true
        t.set_field(target: :extra_scss, name: "my_files/moremagic", value: child_scss)
        t.save!
        theme.add_relative_theme!(:child, t)
      end
    end

    let(:compiler) do
      manager = Stylesheet::Manager.new(theme_id: theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      builder.compile(force: true)
    end

    it "works when importing file by path" do
      theme.set_field(target: :common, name: :scss, value: '@import "my_files/magic";')
      theme.save!

      css, _map = compiler
      expect(css).to include("body{background:red}")
    end

    it "works when importing multiple files" do
      theme.set_field(
        target: :common,
        name: :scss,
        value: '@import "my_files/magic"; @import "my_files/magic2"',
      )
      theme.save!

      css, _map = compiler
      expect(css).to include("body{background:red}")
      expect(css).to include("p{color:blue}")
    end

    it "works for child themes" do
      child_theme.set_field(target: :common, name: :scss, value: '@import "my_files/moremagic"')
      child_theme.save!

      manager = Stylesheet::Manager.new(theme_id: child_theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: child_theme,
          manager: manager,
        )

      css, _map = builder.compile(force: true)
      expect(css).to include("body{background:green}")
    end
  end

  describe "scss_variables" do
    it "is empty by default" do
      expect(theme.scss_variables).to eq(nil)
    end

    it "includes settings and uploads when set" do
      theme.set_field(
        target: :settings,
        name: :yaml,
        value: "background_color: red\nfont_size: 25px",
      )
      upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
      theme.set_field(type: :theme_upload_var, target: :common, name: "bobby", upload_id: upload.id)
      theme.save!

      expect(theme.scss_variables).to include("$background_color: unquote(\"red\")")
      expect(theme.scss_variables).to include("$font_size: unquote(\"25px\")")
      expect(theme.scss_variables).to include("$bobby: ")
    end
  end

  describe "#baked_js_tests_with_digest" do
    before do
      ThemeField.create!(
        theme_id: theme.id,
        target_id: Theme.targets[:settings],
        name: "yaml",
        value: "some_number: 1",
      )
      theme.set_field(
        target: :tests_js,
        type: :js,
        name: "acceptance/some-test.js",
        value: "assert.ok(true);",
      )
      theme.save!
    end

    it "returns nil for content and digest if theme does not have tests" do
      ThemeField.destroy_all
      expect(theme.baked_js_tests_with_digest).to eq([nil, nil])
    end

    it "digest does not change when settings are changed" do
      content, digest = theme.baked_js_tests_with_digest
      expect(content).to be_present
      expect(digest).to be_present
      expect(content).to include("assert.ok(true);")

      theme.update_setting(:some_number, 55)
      theme.save!
      expect(theme.build_settings_hash[:some_number]).to eq(55)

      new_content, new_digest = theme.baked_js_tests_with_digest
      expect(new_content).to eq(content)
      expect(new_digest).to eq(digest)
    end
  end

  describe "#update_setting" do
    it "requests clients to refresh if `refresh: true`" do
      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        super_feature_enabled:
          type: bool
          default: false
          refresh: true
      YAML

      ThemeSetting.create!(
        theme: theme,
        data_type: ThemeSetting.types[:bool],
        name: "super_feature_enabled",
      )
      theme.save!

      messages =
        MessageBus
          .track_publish do
            theme.update_setting(:super_feature_enabled, true)
            theme.save!
          end
          .filter { |m| m.channel == "/global/asset-version" }

      expect(messages.count).to eq(1)
    end

    it "does not request clients to refresh if `refresh: false`" do
      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        super_feature_enabled:
          type: bool
          default: false
          refresh: false
      YAML

      ThemeSetting.create!(
        theme: theme,
        data_type: ThemeSetting.types[:bool],
        name: "super_feature_enabled",
      )
      theme.save!

      messages =
        MessageBus
          .track_publish do
            theme.update_setting(:super_feature_enabled, true)
            theme.save!
          end
          .filter { |m| m.channel == "/global/asset-version" }

      expect(messages.count).to eq(0)
    end
  end

  describe "#lookup_field when a theme component is used in multiple themes" do
    fab!(:theme_1) { Fabricate(:theme, user: user) }
    fab!(:theme_2) { Fabricate(:theme, user: user) }
    fab!(:child) { Fabricate(:theme, user: user, component: true) }

    before_all do
      theme_1.add_relative_theme!(:child, child)
      theme_2.add_relative_theme!(:child, child)
    end

    it "efficiently caches fields of theme component by only caching the fields once across multiple themes" do
      child.set_field(target: :common, name: "header", value: "World")
      child.save!

      expect(Theme.lookup_field(theme_1.id, :desktop, "header")).to eq("World")
      expect(Theme.lookup_field(theme_2.id, :desktop, "header")).to eq("World")

      expect(
        Theme.cache.defer_get_set("#{child.id}:common:header:#{Theme.compiler_version}") { raise },
      ).to eq(["World"])
      expect(
        Theme.cache.defer_get_set("#{child.id}:desktop:header:#{Theme.compiler_version}") { raise },
      ).to eq(nil)

      expect(
        Theme
          .cache
          .defer_get_set("#{theme_1.id}:common:header:#{Theme.compiler_version}") { raise },
      ).to eq(nil)
      expect(
        Theme
          .cache
          .defer_get_set("#{theme_1.id}:desktop:header:#{Theme.compiler_version}") { raise },
      ).to eq(nil)

      expect(
        Theme
          .cache
          .defer_get_set("#{theme_2.id}:common:header:#{Theme.compiler_version}") { raise },
      ).to eq(nil)
      expect(
        Theme
          .cache
          .defer_get_set("#{theme_2.id}:desktop:header:#{Theme.compiler_version}") { raise },
      ).to eq(nil)
    end

    it "puts the parent value ahead of the child" do
      theme_1.set_field(target: :common, name: "header", value: "theme_1")
      theme_1.save!

      child.set_field(target: :common, name: "header", value: "child")
      child.save!

      expect(Theme.lookup_field(theme_1.id, :desktop, "header")).to eq("theme_1\nchild")
    end

    it "puts parent translations ahead of child translations" do
      theme_1.set_field(target: :translations, name: "en", value: <<~YAML)
        en:
          theme_1: "test"
      YAML
      theme_1.save!
      theme_field = ThemeField.order(:id).last

      child.set_field(target: :translations, name: "en", value: <<~YAML)
        en:
          child: "test"
      YAML
      child.save!
      child_field = ThemeField.order(:id).last

      expect(theme_field.value_baked).not_to eq(child_field.value_baked)
      expect(Theme.lookup_field(theme_1.id, :translations, :en)).to eq(
        [theme_field, child_field].map(&:value_baked).join("\n"),
      )
    end

    it "prioritizes a locale over its fallback" do
      theme_1.set_field(target: :translations, name: "en", value: <<~YAML)
        en:
          theme_1: "hello"
      YAML
      theme_1.save!
      en_field = ThemeField.order(:id).last

      theme_1.set_field(target: :translations, name: "es", value: <<~YAML)
        es:
          theme_1: "hola"
      YAML
      theme_1.save!
      es_field = ThemeField.order(:id).last

      expect(es_field.value_baked).not_to eq(en_field.value_baked)
      expect(Theme.lookup_field(theme_1.id, :translations, :en)).to eq(en_field.value_baked)
      expect(Theme.lookup_field(theme_1.id, :translations, :es)).to eq(es_field.value_baked)
      expect(Theme.lookup_field(theme_1.id, :translations, :fr)).to eq(en_field.value_baked)
    end
  end
end
