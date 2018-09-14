require 'rails_helper'

describe Theme do
  after do
    Theme.clear_cache!
  end

  let :user do
    Fabricate(:user)
  end

  let(:guardian) do
    Guardian.new(user)
  end

  let :customization_params do
    { name: 'my name', user_id: user.id, header: "my awesome header" }
  end

  let :customization do
    Fabricate(:theme, customization_params)
  end

  let(:theme) { Fabricate(:theme, user: user) }
  let(:child) { Fabricate(:theme, user: user, component: true) }
  it 'can properly clean up color schemes' do
    scheme = ColorScheme.create!(theme_id: theme.id, name: 'test')
    scheme2 = ColorScheme.create!(theme_id: theme.id, name: 'test2')

    Fabricate(:theme, color_scheme_id: scheme2.id)

    theme.destroy!
    scheme2.reload

    expect(scheme2).not_to eq(nil)
    expect(scheme2.theme_id).to eq(nil)
    expect(ColorScheme.find_by(id: scheme.id)).to eq(nil)
  end

  it 'can support child themes' do
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

    parent.add_child_theme!(child)

    expect(Theme.lookup_field(parent.id, :mobile, "header")).to eq("Common Parent\nMobile Parent\nWorldie\nMobile")

  end

  it 'can correctly find parent themes' do
    theme.add_child_theme!(child)

    expect(child.dependant_themes.length).to eq(1)
  end

  it "doesn't allow multi-level theme components" do
    grandchild = Fabricate(:theme, user: user)
    grandparent = Fabricate(:theme, user: user)

    expect do
      child.add_child_theme!(grandchild)
    end.to raise_error(Discourse::InvalidParameters, I18n.t("themes.errors.no_multilevels_components"))

    expect do
      grandparent.add_child_theme!(theme)
    end.to raise_error(Discourse::InvalidParameters, I18n.t("themes.errors.no_multilevels_components"))
  end

  it "doesn't allow a child to be user selectable" do
    child.update(user_selectable: true)
    expect(child.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_user_selectable"))
  end

  it "doesn't allow a child to be set as the default theme" do
    expect do
      child.set_default!
    end.to raise_error(Discourse::InvalidParameters, I18n.t("themes.errors.component_no_default"))
  end

  it "doesn't allow a component to have color scheme" do
    scheme = ColorScheme.create!(name: "test")
    child.update(color_scheme: scheme)
    expect(child.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_color_scheme"))
  end

  it 'should correct bad html in body_tag_baked and head_tag_baked' do
    theme.set_field(target: :common, name: "head_tag", value: "<b>I am bold")
    theme.save!

    expect(Theme.lookup_field(theme.id, :desktop, "head_tag")).to eq("<b>I am bold</b>")
  end

  it 'should precompile fragments in body and head tags' do
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

    baked = Theme.lookup_field(theme.id, :mobile, "header")

    expect(baked).to match(/HTMLBars/)
    expect(baked).to match(/raw-handlebars/)
  end

  it 'should create body_tag_baked on demand if needed' do
    theme.set_field(target: :common, name: :body_tag, value: "<b>test")
    theme.save

    ThemeField.update_all(value_baked: nil)

    expect(Theme.lookup_field(theme.id, :desktop, :body_tag)).to match(/<b>test<\/b>/)
  end

  it 'can find fields for multiple themes' do
    theme2 = Fabricate(:theme)

    theme.set_field(target: :common, name: :body_tag, value: "<b>testtheme1</b>")
    theme2.set_field(target: :common, name: :body_tag, value: "<b>theme2test</b>")
    theme.save!
    theme2.save!

    field = Theme.lookup_field([theme.id, theme2.id], :desktop, :body_tag)
    expect(field).to match(/<b>testtheme1<\/b>/)
    expect(field).to match(/<b>theme2test<\/b>/)
  end

  describe "#switch_to_component!" do
    it "correctly converts a theme to component" do
      theme.add_child_theme!(child)
      scheme = ColorScheme.create!(name: 'test')
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
      theme.add_child_theme!(child)

      child.switch_to_theme!
      theme.reload
      child.reload

      expect(child.component).to eq(false)
      expect(ChildTheme.where(child_theme: child).exists?).to eq(false)
    end
  end

  describe ".transform_ids" do
    let!(:child) { Fabricate(:theme, component: true) }
    let!(:child2) { Fabricate(:theme, component: true) }

    before do
      theme.add_child_theme!(child)
      theme.add_child_theme!(child2)
    end

    it "adds the child themes of the parent" do
      sorted = [child.id, child2.id].sort

      expect(Theme.transform_ids([theme.id])).to eq([theme.id, *sorted])

      fake_id = [child.id, child2.id, theme.id].min - 5
      fake_id2 = [child.id, child2.id, theme.id].max + 5

      expect(Theme.transform_ids([theme.id, fake_id2, fake_id]))
        .to eq([theme.id, fake_id, *sorted, fake_id2])
    end

    it "doesn't insert children when extend is false" do
      fake_id = theme.id + 1
      fake_id2 = fake_id + 2
      fake_id3 = fake_id2 + 3

      expect(Theme.transform_ids([theme.id], extend: false)).to eq([theme.id])
      expect(Theme.transform_ids([theme.id, fake_id3, fake_id, fake_id2, fake_id2], extend: false))
        .to eq([theme.id, fake_id, fake_id2, fake_id3])
    end
  end

  context "plugin api" do
    def transpile(html)
      f = ThemeField.create!(target_id: Theme.targets[:mobile], theme_id: 1, name: "after_header", value: html)
      f.value_baked
    end

    it "transpiles ES6 code" do
      html = <<HTML
        <script type='text/discourse-plugin' version='0.1'>
          const x = 1;
        </script>
HTML

      transpiled = transpile(html)
      expect(transpiled).to match(/\<script\>/)
      expect(transpiled).to match(/var x = 1;/)
      expect(transpiled).to match(/_registerPluginCode\('0.1'/)
    end

    it "converts errors to a script type that is not evaluated" do
      html = <<HTML
        <script type='text/discourse-plugin' version='0.1'>
          const x = 1;
          x = 2;
        </script>
HTML

      transpiled = transpile(html)
      expect(transpiled).to match(/text\/discourse-js-error/)
      expect(transpiled).to match(/read-only/)
    end
  end

  context 'theme vars' do

    it 'works in parent theme' do
      theme.set_field(target: :common, name: :scss, value: 'body {color: $magic; }')
      theme.set_field(target: :common, name: :magic, value: 'red', type: :theme_var)
      theme.set_field(target: :common, name: :not_red, value: 'red', type: :theme_var)
      theme.component = true
      theme.save

      parent_theme = Fabricate(:theme)
      parent_theme.set_field(target: :common, name: :scss, value: 'body {background-color: $not_red; }')
      parent_theme.set_field(target: :common, name: :not_red, value: 'blue', type: :theme_var)
      parent_theme.save
      parent_theme.add_child_theme!(theme)

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: parent_theme.id)
      expect(scss).to include("color:red")
      expect(scss).to include("background-color:blue")
    end

    it 'can generate scss based off theme vars' do
      theme.set_field(target: :common, name: :scss, value: 'body {color: $magic; content: quote($content)}')
      theme.set_field(target: :common, name: :magic, value: 'red', type: :theme_var)
      theme.set_field(target: :common, name: :content, value: 'Sam\'s Test', type: :theme_var)
      theme.save

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: theme.id)
      expect(scss).to include("red")
      expect(scss).to include('"Sam\'s Test"')
    end

    let :image do
      file_from_fixtures("logo.png")
    end

    it 'can handle uploads based of ThemeField' do
      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      theme.set_field(target: :common, name: :logo, upload_id: upload.id, type: :theme_upload_var)
      theme.set_field(target: :common, name: :scss, value: 'body {background-image: url($logo)}')
      theme.save!

      # make sure we do not nuke it
      freeze_time (SiteSetting.clean_orphan_uploads_grace_period_hours + 1).hours.from_now
      Jobs::CleanUpUploads.new.execute(nil)

      expect(Upload.where(id: upload.id)).to be_exist

      # no error for theme field
      theme.reload
      expect(theme.theme_fields.find_by(name: :scss).error).to eq(nil)

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: theme.id)
      expect(scss).to include(upload.url)
    end
  end

  context "theme settings" do
    it "allows values to be used in scss" do
      theme.set_field(target: :settings, name: :yaml, value: "background_color: red\nfont_size: 25px")
      theme.set_field(target: :common, name: :scss, value: 'body {background-color: $background_color; font-size: $font-size}')
      theme.save!

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: theme.id)
      expect(scss).to include("background-color:red")
      expect(scss).to include("font-size:25px")

      setting = theme.settings.find { |s| s.name == :font_size }
      setting.value = '30px'

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: theme.id)
      expect(scss).to include("font-size:30px")
    end

    it "allows values to be used in JS" do
      theme.set_field(target: :settings, name: :yaml, value: "name: bob")
      theme.set_field(target: :common, name: :after_header, value: '<script type="text/discourse-plugin" version="1.0">alert(settings.name); let a = ()=>{};</script>')
      theme.save!

      transpiled = <<~HTML
      <script>if ('Discourse' in window) {
        Discourse._registerPluginCode('1.0', function (api) {
          var settings = { "name": "bob" };
          alert(settings.name);var a = function a() {};
        });
      }</script>
      HTML

      expect(Theme.lookup_field(theme.id, :desktop, :after_header)).to eq(transpiled.strip)

      setting = theme.settings.find { |s| s.name == :name }
      setting.value = 'bill'

      transpiled = <<~HTML
      <script>if ('Discourse' in window) {
        Discourse._registerPluginCode('1.0', function (api) {
          var settings = { "name": "bill" };
          alert(settings.name);var a = function a() {};
        });
      }</script>
      HTML
      expect(Theme.lookup_field(theme.id, :desktop, :after_header)).to eq(transpiled.strip)

    end

  end

  it 'correctly caches theme ids' do
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

  it 'correctly caches user_themes template' do
    Theme.destroy_all

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"]
    expect(user_themes).to eq([])

    theme = Fabricate(:theme, name: "bob", user_selectable: true)

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
    Theme.find_by(id: id).included_settings.to_json
  end

  it 'handles settings cache correctly' do
    Theme.destroy_all

    expect(cached_settings(theme.id)).to eq("{}")

    theme.set_field(target: :settings, name: "yaml", value: "boolean_setting: true")
    theme.save!
    expect(cached_settings(theme.id)).to match(/\"boolean_setting\":true/)

    theme.settings.first.value = "false"
    expect(cached_settings(theme.id)).to match(/\"boolean_setting\":false/)

    child.set_field(target: :settings, name: "yaml", value: "integer_setting: 54")

    child.save!
    theme.add_child_theme!(child)

    json = cached_settings(theme.id)
    expect(json).to match(/\"boolean_setting\":false/)
    expect(json).to match(/\"integer_setting\":54/)

    expect(cached_settings(child.id)).to eq("{\"integer_setting\":54}")

    child.destroy!
    json = cached_settings(theme.id)
    expect(json).not_to match(/\"integer_setting\":54/)
    expect(json).to match(/\"boolean_setting\":false/)
  end
end
