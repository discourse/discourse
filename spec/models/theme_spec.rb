require 'rails_helper'

describe Theme do

  before do
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
    Theme.create!(customization_params)
  end

  it 'should set default key when creating a new customization' do
    s = Theme.create!(name: 'my name', user_id: user.id)
    expect(s.key).not_to eq(nil)
  end

  it 'can properly clean up color schemes' do
    theme = Theme.create!(name: 'bob', user_id: -1)
    scheme = ColorScheme.create!(theme_id: theme.id, name: 'test')
    scheme2 = ColorScheme.create!(theme_id: theme.id, name: 'test2')

    Theme.create!(name: 'bob', user_id: -1, color_scheme_id: scheme2.id)

    theme.destroy!
    scheme2.reload

    expect(scheme2).not_to eq(nil)
    expect(scheme2.theme_id).to eq(nil)
    expect(ColorScheme.find_by(id: scheme.id)).to eq(nil)
  end

  it 'can support child themes' do
    child = Theme.new(name: '2', user_id: user.id)

    child.set_field(target: :common, name: "header", value: "World")
    child.set_field(target: :desktop, name: "header", value: "Desktop")
    child.set_field(target: :mobile, name: "header", value: "Mobile")

    child.save!

    expect(Theme.lookup_field(child.key, :desktop, "header")).to eq("World\nDesktop")
    expect(Theme.lookup_field(child.key, "mobile", :header)).to eq("World\nMobile")

    child.set_field(target: :common, name: "header", value: "Worldie")
    child.save!

    expect(Theme.lookup_field(child.key, :mobile, :header)).to eq("Worldie\nMobile")

    parent = Theme.new(name: '1', user_id: user.id)

    parent.set_field(target: :common, name: "header", value: "Common Parent")
    parent.set_field(target: :mobile, name: "header", value: "Mobile Parent")

    parent.save!

    parent.add_child_theme!(child)

    expect(Theme.lookup_field(parent.key, :mobile, "header")).to eq("Common Parent\nMobile Parent\nWorldie\nMobile")

  end

  it 'can correctly find parent themes' do
    grandchild = Theme.create!(name: 'grandchild', user_id: user.id)
    child = Theme.create!(name: 'child', user_id: user.id)
    theme = Theme.create!(name: 'theme', user_id: user.id)

    theme.add_child_theme!(child)
    child.add_child_theme!(grandchild)

    expect(grandchild.dependant_themes.length).to eq(2)
  end

  it 'should correct bad html in body_tag_baked and head_tag_baked' do
    theme = Theme.new(user_id: -1, name: "test")
    theme.set_field(target: :common, name: "head_tag", value: "<b>I am bold")
    theme.save!

    expect(Theme.lookup_field(theme.key, :desktop, "head_tag")).to eq("<b>I am bold</b>")
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
    theme = Theme.new(user_id: -1, name: "test")
    theme.set_field(target: :common, name: "header", value: with_template)
    theme.save!

    baked = Theme.lookup_field(theme.key, :mobile, "header")

    expect(baked).to match(/HTMLBars/)
    expect(baked).to match(/raw-handlebars/)
  end

  it 'should create body_tag_baked on demand if needed' do

    theme = Theme.new(user_id: -1, name: "test")
    theme.set_field(target: :common, name: :body_tag, value: "<b>test")
    theme.save

    ThemeField.update_all(value_baked: nil)

    expect(Theme.lookup_field(theme.key, :desktop, :body_tag)).to match(/<b>test<\/b>/)
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

      theme = Theme.new(name: 'theme', user_id: -1)
      theme.set_field(target: :common, name: :scss, value: 'body {color: $magic; }')
      theme.set_field(target: :common, name: :magic, value: 'red', type: :theme_var)
      theme.set_field(target: :common, name: :not_red, value: 'red', type: :theme_var)
      theme.save

      parent_theme = Theme.new(name: 'parent theme', user_id: -1)
      parent_theme.set_field(target: :common, name: :scss, value: 'body {background-color: $not_red; }')
      parent_theme.set_field(target: :common, name: :not_red, value: 'blue', type: :theme_var)
      parent_theme.save
      parent_theme.add_child_theme!(theme)

      scss, _map = Stylesheet::Compiler.compile('@import "theme_variables"; @import "desktop_theme"; ', "theme.scss", theme_id: parent_theme.id)
      expect(scss).to include("color:red")
      expect(scss).to include("background-color:blue")
    end

    it 'can generate scss based off theme vars' do
      theme = Theme.new(name: 'theme', user_id: -1)
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
      theme = Theme.new(name: 'theme', user_id: -1)
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
      theme = Theme.new(name: "awesome theme", user_id: -1)
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
      theme = Theme.new(name: "awesome theme", user_id: -1)
      theme.set_field(target: :settings, name: :yaml, value: "name: bob")
      theme.set_field(target: :common, name: :after_header, value: '<script type="text/discourse-plugin" version="1.0">alert(settings.name); let a = ()=>{};</script>')
      theme.save!

      transpiled = <<~HTML
      <script>Discourse._registerPluginCode('1.0', function (api) {
        var settings = { "name": "bob" };
        alert(settings.name);var a = function a() {};
      });</script>
      HTML

      expect(Theme.lookup_field(theme.key, :desktop, :after_header)).to eq(transpiled.strip)

      setting = theme.settings.find { |s| s.name == :name }
      setting.value = 'bill'

      transpiled = <<~HTML
      <script>Discourse._registerPluginCode('1.0', function (api) {
        var settings = { "name": "bill" };
        alert(settings.name);var a = function a() {};
      });</script>
      HTML
      expect(Theme.lookup_field(theme.key, :desktop, :after_header)).to eq(transpiled.strip)

    end

  end

  it 'correctly caches theme keys' do
    Theme.destroy_all

    theme = Theme.create!(name: "bob", user_id: -1)

    expect(Theme.theme_keys).to eq(Set.new([theme.key]))
    expect(Theme.user_theme_keys).to eq(Set.new([]))

    theme.user_selectable = true
    theme.save

    expect(Theme.user_theme_keys).to eq(Set.new([theme.key]))

    theme.user_selectable = false
    theme.save

    theme.set_default!
    expect(Theme.user_theme_keys).to eq(Set.new([theme.key]))

    theme.destroy

    expect(Theme.theme_keys).to eq(Set.new([]))
    expect(Theme.user_theme_keys).to eq(Set.new([]))
  end

  it 'correctly caches user_themes template' do
    Theme.destroy_all

    json = Site.json_for(guardian)
    user_themes = JSON.parse(json)["user_themes"]
    expect(user_themes).to eq([])

    theme = Theme.create!(name: "bob", user_id: -1, user_selectable: true)
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

  def cached_settings(key)
    Theme.settings_for_client(key) # returns json
  end

  it 'handles settings cache correctly' do
    Theme.destroy_all
    expect(cached_settings(nil)).to eq("{}")

    theme = Theme.create!(name: "awesome theme", user_id: -1)
    theme.save!
    expect(cached_settings(theme.key)).to eq("{}")

    theme.set_field(target: :settings, name: "yaml", value: "boolean_setting: true")
    theme.save!
    expect(cached_settings(theme.key)).to match(/\"boolean_setting\":true/)

    theme.settings.first.value = "false"
    expect(cached_settings(theme.key)).to match(/\"boolean_setting\":false/)

    child = Theme.create!(name: "child theme", user_id: -1)
    child.set_field(target: :settings, name: "yaml", value: "integer_setting: 54")

    child.save!
    theme.add_child_theme!(child)

    json = cached_settings(theme.key)
    expect(json).to match(/\"boolean_setting\":false/)
    expect(json).to match(/\"integer_setting\":54/)

    expect(cached_settings(child.key)).to eq("{\"integer_setting\":54}")

    child.destroy!
    json = cached_settings(theme.key)
    expect(json).not_to match(/\"integer_setting\":54/)
    expect(json).to match(/\"boolean_setting\":false/)
  end

end
