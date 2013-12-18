require 'spec_helper'

describe SiteCustomization do

  let :user do
    Fabricate(:user)
  end

  let :customization_params do
    {name: 'my name', user_id: user.id, header: "my awesome header", stylesheet: "my awesome css", mobile_stylesheet: nil, mobile_header: nil}
  end

  let :customization do
    SiteCustomization.create!(customization_params)
  end

  let :customization_with_mobile do
    SiteCustomization.create!(customization_params.merge(mobile_stylesheet: ".mobile {better: true;}", mobile_header: "fancy mobile stuff"))
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
      File.delete(c.stylesheet_fullpath(:mobile))

      SiteCustomization.custom_stylesheet(c.key)
      File.exists?(c.stylesheet_fullpath).should == true
      File.exists?(c.stylesheet_fullpath(:mobile)).should == true
    end

    context '#custom_stylesheet' do
      it 'should allow me to lookup a filename containing my preview stylesheet' do
        SiteCustomization.custom_stylesheet(customization.key).should ==
          "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/uploads/stylesheet-cache/#{customization.key}.css?#{customization.stylesheet_hash}\" type=\"text/css\" media=\"screen\">"
      end

      it "should return blank link tag for mobile if mobile_stylesheet is blank" do
        SiteCustomization.custom_stylesheet(customization.key, :mobile).should == ""
      end

      it "should return link tag for mobile custom stylesheet" do
        SiteCustomization.custom_stylesheet(customization_with_mobile.key, :mobile).should ==
          "<link class=\"custom-css\" rel=\"stylesheet\" href=\"/uploads/stylesheet-cache/mobile_#{customization_with_mobile.key}.css?#{customization_with_mobile.stylesheet_hash(:mobile)}\" type=\"text/css\" media=\"screen\">"
      end
    end

    context '#custom_header' do
      it "returns empty string when there is no custom header" do
        c = SiteCustomization.create!(customization_params.merge(header: ''))
        SiteCustomization.custom_header(c.key).should == ''
      end

      it "can return the custom header html" do
        SiteCustomization.custom_header(customization.key).should == customization_params[:header]
      end

      it "returns empty string for mobile header when there's no custom mobile header" do
        SiteCustomization.custom_header(customization.key, :mobile).should == ''
      end

      it "can return the custom mobile header html" do
        SiteCustomization.custom_header(customization_with_mobile.key, :mobile).should == customization_with_mobile.mobile_header
      end
    end

    it 'should fix stylesheet files after changing the stylesheet' do
      old_file = customization.stylesheet_fullpath
      original = SiteCustomization.custom_stylesheet(customization.key)

      File.exists?(old_file).should == true
      customization.stylesheet = "div { clear:both; }"
      customization.save

      SiteCustomization.custom_stylesheet(customization.key).should_not == original
    end

    it 'should fix mobile stylesheet files after changing the mobile_stylesheet' do
      old_file = customization_with_mobile.stylesheet_fullpath(:mobile)
      original = SiteCustomization.custom_stylesheet(customization_with_mobile.key, :mobile)

      File.exists?(old_file).should == true
      customization_with_mobile.mobile_stylesheet = "div { clear:both; }"
      customization_with_mobile.save

      SiteCustomization.custom_stylesheet(customization_with_mobile.key).should_not == original
    end

    it 'should delete old stylesheet files after deleting' do
      old_file = customization.stylesheet_fullpath
      customization.ensure_stylesheets_on_disk!
      customization.destroy
      File.exists?(old_file).should == false
    end

    it 'should delete old mobile stylesheet files after deleting' do
      old_file = customization_with_mobile.stylesheet_fullpath(:mobile)
      customization_with_mobile.ensure_stylesheets_on_disk!
      customization_with_mobile.destroy
      File.exists?(old_file).should == false
    end

    it 'should nuke old revs out of the cache' do
      old_style = SiteCustomization.custom_stylesheet(customization.key)

      customization.stylesheet = "hello worldz"
      customization.save
      SiteCustomization.custom_stylesheet(customization.key).should_not == old_style
    end

    it 'should nuke old revs out of the cache for mobile too' do
      old_style = SiteCustomization.custom_stylesheet(customization_with_mobile.key)

      customization_with_mobile.mobile_stylesheet = "hello worldz"
      customization_with_mobile.save
      SiteCustomization.custom_stylesheet(customization.key, :mobile).should_not == old_style
    end


    it 'should compile scss' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '$black: #000; #a { color: $black; }', header: '')
      c.stylesheet_baked.should == "#a {\n  color: black; }\n"
    end

    it 'should compile mobile scss' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '', header: '', mobile_stylesheet: '$black: #000; #a { color: $black; }', mobile_header: '')
      c.mobile_stylesheet_baked.should == "#a {\n  color: black; }\n"
    end

    it 'should provide an awesome error on failure' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: "$black: #000; #a { color: $black; }\n\n\nboom", header: '')
      c.stylesheet_baked.should =~ /Syntax error/
      c.mobile_stylesheet_baked.should_not be_present
    end

    it 'should provide an awesome error on failure for mobile too' do
      c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '', header: '', mobile_stylesheet: "$black: #000; #a { color: $black; }\n\n\nboom", mobile_header: '')
      c.mobile_stylesheet_baked.should =~ /Syntax error/
      c.stylesheet_baked.should_not be_present
    end

  end

end
