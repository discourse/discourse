# frozen_string_literal: true

describe 'Styleguide assets' do
  before do
    SiteSetting.styleguide_enabled = true
    sign_in(Fabricate(:admin))
  end

  context 'visits homepage' do
    it 'doesn’t load styleguide assets' do
      get '/'
      expect(response.body).to_not include('styleguide')
    end
  end

  context 'visits styleguide' do
    it 'loads styleguide assets' do
      get '/styleguide'
      expect(response.body).to include('styleguide')
    end
  end
end
