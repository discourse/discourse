require 'rails_helper'

describe SiteCustomizationsController do

  before do
    SiteCustomization.clear_cache!
  end

  it 'can deliver enabled css' do
    SiteCustomization.create!(name: '1',
                              user_id: -1,
                              enabled: true,
                              mobile_stylesheet: '.a1{margin: 1px;}',
                              stylesheet: '.b1{margin: 1px;}'
                             )

    SiteCustomization.create!(name: '2',
                              user_id: -1,
                              enabled: true,
                              mobile_stylesheet: '.a2{margin: 1px;}',
                              stylesheet: '.b2{margin: 1px;}'
                             )

    get :show, key: SiteCustomization::ENABLED_KEY, format: :css, target: 'mobile'
    expect(response.body).to match(/\.a1.*\.a2/m)

    get :show, key: SiteCustomization::ENABLED_KEY, format: :css
    expect(response.body).to match(/\.b1.*\.b2/m)
  end

  it 'can deliver specific css' do
    c = SiteCustomization.create!(name: '1',
                              user_id: -1,
                              enabled: true,
                              mobile_stylesheet: '.a1{margin: 1px;}',
                              stylesheet: '.b1{margin: 1px;}'
                             )

    get :show, key: c.key, format: :css, target: 'mobile'
    expect(response.body).to match(/\.a1/)

    get :show, key: c.key, format: :css
    expect(response.body).to match(/\.b1/)
  end
end
