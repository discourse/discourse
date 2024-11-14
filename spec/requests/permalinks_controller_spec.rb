# frozen_string_literal: true

RSpec.describe PermalinksController do
  fab!(:topic)
  fab!(:permalink) { Fabricate(:permalink, url: "deadroute/topic/546") }

  describe "show" do
    it "should redirect to a permalink's target_url with status 301" do
      permalink.update!(permalink_type_value: topic.id, permalink_type: "topic")

      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should work for subfolder installs too" do
      permalink.update!(permalink_type_value: topic.id, permalink_type: "topic")
      set_subfolder "/forum"

      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should apply normalizations" do
      permalink.update!(permalink_type_value: "/topic/100", permalink_type: "external_url")
      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1"

      get "/#{permalink.url}", params: { test: "hello" }

      expect(response).to redirect_to("/topic/100")
      expect(response.status).to eq(301)

      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1X"

      get "/#{permalink.url}", params: { test: "hello" }

      expect(response.status).to eq(404)
    end

    it "return 404 if permalink record does not exist" do
      get "/not/a/valid/url"
      expect(response.status).to eq(404)
    end

    context "when permalink's target_url is an external URL" do
      before do
        permalink.update!(
          permalink_type_value: "https://github.com/discourse/discourse",
          permalink_type: "external_url",
        )
      end

      it "redirects to it properly" do
        get "/#{permalink.url}"
        expect(response).to redirect_to(permalink.external_url)
      end
    end
  end
end
