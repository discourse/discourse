# frozen_string_literal: true

RSpec.describe PermalinksController do
  fab!(:topic)
  fab!(:permalink) { Fabricate(:permalink, url: "deadroute/topic/546", topic:) }

  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:private_topic) do
    Fabricate(:topic, category: private_category, title: "This is a secret title")
  end

  fab!(:group_member) { Fabricate(:user, groups: [group]) }
  fab!(:non_member, :user)
  fab!(:admin)

  describe "show" do
    it "should redirect to a permalink's target_url with status 301" do
      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should work for subfolder installs too" do
      set_subfolder "/forum"

      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should apply normalizations" do
      permalink.update!(external_url: "/topic/100", topic_id: nil)
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
      it "redirects to it properly" do
        permalink.update!(external_url: "https://github.com/discourse/discourse", topic_id: nil)

        get "/#{permalink.url}"
        expect(response).to redirect_to(permalink.external_url)
      end
    end

    context "when permalink points to a restricted topic" do
      it "returns 404 for anonymous users" do
        permalink = Fabricate(:permalink, url: "secret", topic: private_topic)

        get "/#{permalink.url}"

        expect(response.status).to eq(404)
        expect(response.headers["Location"]).to be_nil
      end

      it "returns 404 for logged-in users without access" do
        sign_in(non_member)
        permalink = Fabricate(:permalink, url: "secret-logged-in", topic: private_topic)

        get "/#{permalink.url}"

        expect(response.status).to eq(404)
        expect(response.headers["Location"]).to be_nil
      end

      it "redirects users who have access to the topic" do
        sign_in(group_member)
        permalink = Fabricate(:permalink, url: "secret-member", topic: private_topic)

        get "/#{permalink.url}"

        expect(response.status).to eq(301)
        expect(response).to redirect_to(private_topic.relative_url)
      end

      it "redirects admins to the topic" do
        sign_in(admin)
        permalink = Fabricate(:permalink, url: "secret-admin", topic: private_topic)

        get "/#{permalink.url}"

        expect(response.status).to eq(301)
        expect(response).to redirect_to(private_topic.relative_url)
      end
    end

    context "when permalink points to a restricted category" do
      it "returns 404 for anonymous users" do
        permalink = Fabricate(:permalink, url: "hidden", category: private_category)

        get "/#{permalink.url}"

        expect(response.status).to eq(404)
        expect(response.headers["Location"]).to be_nil
      end
    end

    context "when permalink points to a post in a restricted topic" do
      it "returns 404 for anonymous users" do
        private_post = Fabricate(:post, topic: private_topic)
        permalink = Fabricate(:permalink, url: "secret-post", post: private_post)

        get "/#{permalink.url}"

        expect(response.status).to eq(404)
        expect(response.headers["Location"]).to be_nil
      end
    end

    context "when permalink points to a hidden tag" do
      it "returns 404 for anonymous users" do
        tag = Fabricate(:tag, name: "secret-internal-tag")
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])

        permalink = Fabricate(:permalink, url: "internal-tag", tag:)

        get "/#{permalink.url}"

        expect(response.status).to eq(404)
        expect(response.headers["Location"]).to be_nil
      end
    end
  end

  describe "check" do
    context "when permalink points to a restricted topic" do
      it "reports not found for anonymous users" do
        permalink = Fabricate(:permalink, url: "secret-check", topic: private_topic)

        get "/permalink-check.json", params: { path: permalink.url }

        json = response.parsed_body
        expect(json["found"]).to eq(false)
        expect(json["target_url"]).to be_nil
      end
    end

    context "when permalink points to a restricted category" do
      it "reports not found for anonymous users" do
        permalink = Fabricate(:permalink, url: "hidden-check", category: private_category)

        get "/permalink-check.json", params: { path: permalink.url }

        json = response.parsed_body
        expect(json["found"]).to eq(false)
        expect(json["target_url"]).to be_nil
      end
    end
  end
end
