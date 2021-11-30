# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RobotsTxtController do
  describe '#builder' do
    it "returns json information for building a robots.txt" do
      get "/robots-builder.json"
      json = response.parsed_body
      expect(json).to be_present
      expect(json['header']).to be_present
      expect(json['agents']).to be_present
    end

    it "includes overridden content if robots.txt is is overridden" do
      SiteSetting.overridden_robots_txt = "something"

      get "/robots-builder.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json['header']).to be_present
      expect(json['agents']).to be_present
      expect(json['overridden']).to eq("something")
    end
  end

  describe '#index' do

    context "header for when the content is overridden" do
      it "is not prepended if there are no overrides" do
        sign_in(Fabricate(:admin))
        get '/robots.txt'
        expect(response.body).not_to start_with(RobotsTxtController::OVERRIDDEN_HEADER)
      end

      it "is prepended if there are overrides and the user is admin" do
        SiteSetting.overridden_robots_txt = "overridden_content"
        sign_in(Fabricate(:admin))
        get '/robots.txt'
        expect(response.body).to start_with(RobotsTxtController::OVERRIDDEN_HEADER)
      end

      it "is not prepended if the user is not admin" do
        SiteSetting.overridden_robots_txt = "overridden_content"
        get '/robots.txt'
        expect(response.body).not_to start_with(RobotsTxtController::OVERRIDDEN_HEADER)
      end
    end

    context 'subfolder' do
      it 'prefixes the rules with the directory' do
        set_subfolder "/forum"

        get '/robots.txt'
        expect(response.body).to include("\nDisallow: /forum/email/")
      end
    end

    context 'allow_index_in_robots_txt is true' do

      def expect_allowed_and_disallowed_sections(allow_index, disallow_index)
        expect(allow_index).to be_present
        expect(disallow_index).to be_present

        allow_section = allow_index < disallow_index ?
          response.body[allow_index...disallow_index] : response.body[allow_index..-1]

        expect(allow_section).to include('Disallow: /auth/')
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
        expect(response.body[i..-1]).to include("Disallow: /auth/")
        # we have to insert Googlebot for special handling
        expect(response.body[i..-1]).to include("User-agent: Googlebot")
      end

      it "can allowlist user agents" do
        SiteSetting.allowed_crawler_user_agents = "Googlebot|Twitterbot"
        get '/robots.txt'
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')

        allowed_index = [response.body.index('User-agent: Googlebot'), response.body.index('User-agent: Twitterbot')].min
        disallow_all_index = response.body.index('User-agent: *')

        expect_allowed_and_disallowed_sections(allowed_index, disallow_all_index)
      end

      it "can blocklist user agents" do
        SiteSetting.blocked_crawler_user_agents = "Googlebot|Twitterbot"
        get '/robots.txt'
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')

        disallow_index = [response.body.index('User-agent: Googlebot'), response.body.index('User-agent: Twitterbot')].min
        allow_index = response.body.index('User-agent: *')

        expect_allowed_and_disallowed_sections(allow_index, disallow_index)
      end

      it "ignores blocklist if allowlist is set" do
        SiteSetting.allowed_crawler_user_agents = "Googlebot|Twitterbot"
        SiteSetting.blocked_crawler_user_agents = "Bananabot"
        get '/robots.txt'
        expect(response.body).to_not include('Bananabot')
        expect(response.body).to include('User-agent: Googlebot')
        expect(response.body).to include('User-agent: Twitterbot')
      end
    end

    it "returns noindex when indexing is disallowed" do
      SiteSetting.allow_index_in_robots_txt = false
      get '/robots.txt'

      expect(response.body).to_not include("Disallow: /auth/")
      expect(response.body).to include("User-agent: googlebot\nAllow")
    end

    it "returns overridden robots.txt if the file is overridden" do
      SiteSetting.overridden_robots_txt = "blah whatever"
      get '/robots.txt'
      expect(response.status).to eq(200)
      expect(response.body).to eq(SiteSetting.overridden_robots_txt)
    end
  end
end
