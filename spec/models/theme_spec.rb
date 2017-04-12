require 'rails_helper'

describe Theme do

  before do
    Theme.clear_cache!
  end

  let :user do
    Fabricate(:user)
  end

  let :customization_params do
    {name: 'my name', user_id: user.id, header: "my awesome header"}
  end

  let :customization do
    Theme.create!(customization_params)
  end

  it 'should set default key when creating a new customization' do
    s = Theme.create!(name: 'my name', user_id: user.id)
    expect(s.key).not_to eq(nil)
  end

  it 'can support child themes' do
    child = Theme.new(name: '2', user_id: user.id)

    child.set_field(:common, "header", "World")
    child.set_field(:desktop, "header", "Desktop")
    child.set_field(:mobile, "header", "Mobile")

    child.save!

    expect(Theme.lookup_field(child.key, :desktop, "header")).to eq("World\nDesktop")
    expect(Theme.lookup_field(child.key, "mobile", :header)).to eq("World\nMobile")


    child.set_field(:common, "header", "Worldie")
    child.save!

    expect(Theme.lookup_field(child.key, :mobile, :header)).to eq("Worldie\nMobile")

    parent = Theme.new(name: '1', user_id: user.id)

    parent.set_field(:common, "header", "Common Parent")
    parent.set_field(:mobile, "header", "Mobile Parent")

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
    theme.set_field(:common, "head_tag", "<b>I am bold")
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
    theme.set_field(:common, "header", with_template)
    theme.save!

    baked = Theme.lookup_field(theme.key, :mobile, "header")

    expect(baked).to match(/HTMLBars/)
    expect(baked).to match(/raw-handlebars/)
  end

  it 'should create body_tag_baked on demand if needed' do

    theme = Theme.new(user_id: -1, name: "test")
    theme.set_field(:common, :body_tag, "<b>test")
    theme.save

    ThemeField.update_all(value_baked: nil)

    expect(Theme.lookup_field(theme.key, :desktop, :body_tag)).to match(/<b>test<\/b>/)
  end

  context "plugin api" do
    def transpile(html)
      f = ThemeField.create!(target: Theme.targets[:mobile], theme_id: -1, name: "after_header", value: html)
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


end
