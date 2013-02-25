require 'spec_helper'

describe SiteCustomization do

  let :user do
    Fabricate(:user)
  end

  let :customization do
    SiteCustomization.create!(name: 'my name', user_id: user.id, header: "my awesome header", stylesheet: "my awesome css")
  end

  it 'should set default key when creating a new customization' do
    s = SiteCustomization.create!(name: 'my name', user_id: user.id)
    s.key.should_not == nil
  end

  context 'caching' do

    context 'enabled style' do
      before do
        @customization = customization
      end

      it 'finds no style when none enabled' do
        SiteCustomization.enabled_style_key.should be_nil
      end


      it 'finds the enabled style' do
        @customization.enabled = true
        @customization.save
        SiteCustomization.enabled_style_key.should == @customization.key
      end

      it 'finds no enabled style on other sites' do
        @customization.enabled = true
        @customization.save

        RailsMultisite::ConnectionManagement.expects(:current_db).returns("foo").twice
        # the mocking is tricky, lets remove the record so we can properly pretend we are on another db
        #  this bypasses the before / after stuff
        SiteCustomization.exec_sql('delete from site_customizations')

        SiteCustomization.enabled_style_key.should be_nil
      end
    end

    it 'ensure stylesheet is on disk on first fetch' do
      c = customization
      c.remove_from_cache!
      File.delete(c.stylesheet_fullpath)

      SiteCustomization.custom_stylesheet(c.key)
      File.exists?(c.stylesheet_fullpath).should == true

    end

    it 'should allow me to lookup a filename containing my preview stylesheet' do
      SiteCustomization.custom_stylesheet(customization.key).should ==
        "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/uploads/stylesheet-cache/#{customization.key}.css?#{customization.stylesheet_hash}\" type=\"text/css\" media=\"screen\">"
    end

    it 'should fix stylesheet files after changing the stylesheet' do
      old_file = customization.stylesheet_fullpath
      original = SiteCustomization.custom_stylesheet(customization.key)

      File.exists?(old_file).should == true
      customization.stylesheet = "div { clear:both; }"
      customization.save

      SiteCustomization.custom_stylesheet(customization.key).should_not == original
    end

    it 'should delete old stylesheet files after deleting' do
      old_file = customization.stylesheet_fullpath
      customization.ensure_stylesheet_on_disk!
      customization.destroy
      File.exists?(old_file).should == false
    end

    it 'should nuke old revs out of the cache' do
      old_style = SiteCustomization.custom_stylesheet(customization.key)

      customization.stylesheet = "hello worldz"
      customization.save
      SiteCustomization.custom_stylesheet(customization.key).should_not == old_style
    end


    it 'should compile scss' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '$black: #000; #a { color: $black; }', header: '')
      c.stylesheet_baked.should == "#a {\n  color: black; }\n"
    end

    it 'should provide an awesome error on failure' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: "$black: #000; #a { color: $black; }\n\n\nboom", header: '')

      c.stylesheet_baked.should =~ /Syntax error/
    end

  end

end
