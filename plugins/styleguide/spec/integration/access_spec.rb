# frozen_string_literal: true

describe 'SiteSetting.styleguide_admin_only' do
  before do
    SiteSetting.styleguide_enabled = true
  end

  context 'styleguide is admin only' do
    before do
      SiteSetting.styleguide_admin_only = true
    end

    context 'user is admin' do
      before do
        sign_in(Fabricate(:admin))
      end

      it 'shows the styleguide' do
        get '/styleguide'
        expect(response.status).to eq(200)
      end
    end

    context 'user is not admin' do
      before do
        sign_in(Fabricate(:user))
      end

      it 'doesn’t allow access' do
        get '/styleguide'
        expect(response.status).to eq(403)
      end
    end
  end
end

describe 'SiteSetting.styleguide_enabled' do
  before do
    sign_in(Fabricate(:admin))
  end

  context 'style is enabled' do
    before do
      SiteSetting.styleguide_enabled = true
    end

    it 'shows the styleguide' do
      get '/styleguide'
      expect(response.status).to eq(200)
    end
  end

  context 'styleguide is disabled' do
    before do
      SiteSetting.styleguide_enabled = false
    end

    it 'returns a page not found' do
      get '/styleguide'
      expect(response.status).to eq(404)
    end
  end
end
