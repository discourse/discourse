require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#redirect_to_login_if_required' do
    let(:admin) { Fabricate(:admin) }

    before do
      admin  # to skip welcome wizard at home page `/`
      SiteSetting.login_required = true
    end

    it "should carry-forward authComplete param to login page redirect" do
      get "/?authComplete=true"
      expect(response).to redirect_to('/login?authComplete=true')
    end
  end

  describe 'build_not_found_page' do
    describe 'topic not found' do
      it 'should return 404 and show Google search' do
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(I18n.t('page_not_found.search_google'))
      end

      it 'should not include Google search if login_required is enabled' do
        SiteSetting.login_required = true
        sign_in(Fabricate(:user))
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to_not include('google.com/search')
      end
    end
  end

  context "crawler blocking" do
    let :non_crawler do
      {
        "HTTP_USER_AGENT" =>
        "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
      }
    end
    it "applies whitelisted_crawler_user_agents correctly" do
      SiteSetting.whitelisted_crawler_user_agents = 'Googlebot'

      get '/srv/status', headers: {
        'HTTP_USER_AGENT' => 'Googlebot/2.1 (+http://www.google.com/bot.html)'
      }

      expect(response.status).to eq(200)

      get '/srv/status', headers: {
        'HTTP_USER_AGENT' => 'Anotherbot/2.1 (+http://www.notgoogle.com/bot.html)'
      }

      expect(response.status).to eq(403)

      get '/srv/status', headers: non_crawler
      expect(response.status).to eq(200)
    end

    it "applies blacklisted_crawler_user_agents correctly" do
      SiteSetting.blacklisted_crawler_user_agents = 'Googlebot'

      get '/srv/status', headers: non_crawler
      expect(response.status).to eq(200)

      get '/srv/status', headers: {
        'HTTP_USER_AGENT' => 'Googlebot/2.1 (+http://www.google.com/bot.html)'
      }

      expect(response.status).to eq(403)

      get '/srv/status', headers: {
        'HTTP_USER_AGENT' => 'Twitterbot/2.1 (+http://www.notgoogle.com/bot.html)'
      }

      expect(response.status).to eq(200)
    end

    it "blocked crawlers shouldn't log page views" do
      ApplicationRequest.clear_cache!
      SiteSetting.blacklisted_crawler_user_agents = 'Googlebot'
      expect {
        get '/srv/status', headers: {
          'HTTP_USER_AGENT' => 'Googlebot/2.1 (+http://www.google.com/bot.html)'
        }
        ApplicationRequest.write_cache!
      }.to_not change { ApplicationRequest.count }
    end

    it "blocks json requests" do
      SiteSetting.blacklisted_crawler_user_agents = 'Googlebot'

      get '/srv/status.json', headers: {
        'HTTP_USER_AGENT' => 'Googlebot/2.1 (+http://www.google.com/bot.html)'
      }

      expect(response.status).to eq(403)
    end
  end

end
