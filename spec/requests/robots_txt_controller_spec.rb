require 'rails_helper'

RSpec.describe RobotsTxtController do
  describe '#builder' do
    it "returns json information for building a robots.txt" do
      get "/robots-builder.json"
      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['header']).to be_present
      expect(json['agents']).to be_present
    end
  end

  describe '#index' do

    context 'subfolder' do
      it 'prefixes the rules with the directory' do
        Discourse.stubs(:base_uri).returns('/forum')
        get '/robots.txt'
        expect(response.body).to include("\nDisallow: /forum/admin")
        expect(response.body).to include("\nNoindex: /forum/admin")
      end
    end

    context 'crawl delay' do
      it 'allows you to set crawl delay on particular bots' do
        SiteSetting.allow_index_in_robots_txt = true
        SiteSetting.slow_down_crawler_rate = 17
        SiteSetting.slow_down_crawler_user_agents = 'bingbot|googlebot'
        get '/robots.txt'
        expect(response.body).to include("\nUser-agent: bingbot\nCrawl-delay: 17")
        expect(response.body).to include("\nUser-agent: googlebot\nCrawl-delay: 17")
      end
    end

    context 'allow_index_in_robots_txt is true' do

      def expect_allowed_and_disallowed_sections(allow_index, disallow_index)
        expect(allow_index).to be_present
        expect(disallow_index).to be_present

        allow_section = allow_index < disallow_index ?
          response.body[allow_index...disallow_index] : response.body[allow_index..-1]

        expect(allow_section).to include('Disallow: /u/')
        expect(allow_section).to_not include("Disallow: /\n")

        disallowed_section = allow_index < disallow_index ?
          response.body[disallow_index..-1] : response.body[disallow_index...allow_index]
        expect(disallowed_section).to include("Disallow: /\n")
      end

      it "returns index when indexing is allowed" do
        SiteSetting.allow_index_in_robots_txt = true
        get '/robots.txt'

        i = response.body.index('User-agent: *')
        expect(i).to be_present
        expect(response.body[i..-1]).to include("Disallow: /u/")
      end

      it "can whitelist user agents" do
        SiteSetting.whitelisted_crawler_user_agents = "Googlebot|Twitterbot"
        get '/robots.txt'
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')

        allowed_index = [response.body.index('User-agent: Googlebot'), response.body.index('User-agent: Twitterbot')].min
        disallow_all_index = response.body.index('User-agent: *')

        expect_allowed_and_disallowed_sections(allowed_index, disallow_all_index)
      end

      it "can blacklist user agents" do
        SiteSetting.blacklisted_crawler_user_agents = "Googlebot|Twitterbot"
        get '/robots.txt'
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')

        disallow_index = [response.body.index('User-agent: Googlebot'), response.body.index('User-agent: Twitterbot')].min
        allow_index = response.body.index('User-agent: *')

        expect_allowed_and_disallowed_sections(allow_index, disallow_index)
      end

      it "ignores blacklist if whitelist is set" do
        SiteSetting.whitelisted_crawler_user_agents = "Googlebot|Twitterbot"
        SiteSetting.blacklisted_crawler_user_agents = "Bananabot"
        get '/robots.txt'
        expect(response.body).to_not include('Bananabot')
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')
      end
    end

    it "returns noindex when indexing is disallowed" do
      SiteSetting.allow_index_in_robots_txt = false
      get '/robots.txt'

      expect(response.body).to_not include("Disallow: /u/")
    end
  end
end
