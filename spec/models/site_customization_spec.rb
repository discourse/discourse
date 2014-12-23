require 'spec_helper'

describe SiteCustomization do

  before do
    SiteCustomization.clear_cache!
  end

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

  it 'can enable more than one style at once' do
    c1 = SiteCustomization.create!(name: '2', user_id: user.id, header: 'World',
                              enabled: true, mobile_header: 'hi', footer: 'footer',
                              stylesheet: '.hello{.world {color: blue;}}')

    SiteCustomization.create!(name: '1', user_id: user.id, header: 'Hello',
                              enabled: true, mobile_footer: 'mfooter',
                              mobile_stylesheet: '.hello{margin: 1px;}',
                              stylesheet: 'p{width: 1px;}'
                             )

    SiteCustomization.custom_header.should == "Hello\nWorld"
    SiteCustomization.custom_header(nil, :mobile).should == "hi"
    SiteCustomization.custom_footer(nil, :mobile).should == "mfooter"
    SiteCustomization.custom_footer.should == "footer"

    desktop_css = SiteCustomization.custom_stylesheet
    desktop_css.should =~ Regexp.new("#{SiteCustomization::ENABLED_KEY}.css\\?target=desktop")

    mobile_css = SiteCustomization.custom_stylesheet(nil, :mobile)
    mobile_css.should =~  Regexp.new("#{SiteCustomization::ENABLED_KEY}.css\\?target=mobile")

    SiteCustomization.enabled_stylesheet_contents.should =~ /\.hello \.world/

    # cache expiry
    c1.enabled = false
    c1.save

    SiteCustomization.custom_stylesheet.should_not == desktop_css
    SiteCustomization.enabled_stylesheet_contents.should_not =~ /\.hello \.world/
  end

  it 'should be able to look up stylesheets by key' do
    c = SiteCustomization.create!(name: '2', user_id: user.id,
                              enabled: true,
                              stylesheet: '.hello{.world {color: blue;}}',
                              mobile_stylesheet: '.world{.hello{color: black;}}')

    SiteCustomization.custom_stylesheet(c.key, :mobile).should =~ Regexp.new("#{c.key}.css\\?target=mobile")
    SiteCustomization.custom_stylesheet(c.key).should =~ Regexp.new("#{c.key}.css\\?target=desktop")

  end


  it 'should allow including discourse styles' do
    c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '@import "desktop";', mobile_stylesheet: '@import "mobile";')
    c.stylesheet_baked.should_not =~ /Syntax error/
    c.stylesheet_baked.length.should be > 1000
    c.mobile_stylesheet_baked.should_not =~ /Syntax error/
    c.mobile_stylesheet_baked.length.should be > 1000
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
