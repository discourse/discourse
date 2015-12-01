require 'rails_helper'

describe PermalinksController do
  describe 'show' do
    it "should redirect to a permalink's target_url with status 301" do
      permalink = Fabricate(:permalink)
      Permalink.any_instance.stubs(:target_url).returns('/t/the-topic-slug/42')
      get :show, url: permalink.url
      expect(response).to redirect_to('/t/the-topic-slug/42')
      expect(response.status).to eq(301)
    end

    it "should work for subfolder installs too" do
      GlobalSetting.stubs(:relative_url_root).returns('/forum')
      Discourse.stubs(:base_uri).returns("/forum")
      permalink = Fabricate(:permalink)
      Permalink.any_instance.stubs(:target_url).returns('/forum/t/the-topic-slug/42')
      get :show, url: permalink.url
      expect(response).to redirect_to('/forum/t/the-topic-slug/42')
      expect(response.status).to eq(301)
    end

    it "should apply normalizations" do
      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1"

      permalink = Fabricate(:permalink, url: '/topic/bla', external_url: '/topic/100')

      get :show, url: permalink.url, test: "hello"

      expect(response).to redirect_to('/topic/100')
      expect(response.status).to eq(301)

      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1X"

      get :show, url: permalink.url, test: "hello"

      expect(response.status).to eq(404)
    end

    it 'return 404 if permalink record does not exist' do
      get :show, url: '/not/a/valid/url'
      expect(response.status).to eq(404)
    end
  end

end
