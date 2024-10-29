# frozen_string_literal: true

RSpec.describe Admin::PermalinksController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "filters url" do
        Fabricate(:permalink, url: "/forum/23")
        Fabricate(:permalink, url: "/forum/98")
        Fabricate(:permalink, url: "/discuss/topic/45")
        Fabricate(:permalink, url: "/discuss/topic/76")

        get "/admin/permalinks.json", params: { filter: "topic" }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result.length).to eq(2)
      end

      it "filters external url" do
        Fabricate(:permalink, external_url: "http://google.com")
        Fabricate(:permalink, external_url: "http://wikipedia.org")
        Fabricate(:permalink, external_url: "http://www.discourse.org")
        Fabricate(:permalink, external_url: "http://try.discourse.org")

        get "/admin/permalinks.json", params: { filter: "discourse" }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result.length).to eq(2)
      end

      it "filters url and external url both" do
        Fabricate(:permalink, url: "/forum/23", external_url: "http://google.com")
        Fabricate(:permalink, url: "/discourse/98", external_url: "http://wikipedia.org")
        Fabricate(:permalink, url: "/discuss/topic/45", external_url: "http://discourse.org")
        Fabricate(:permalink, url: "/discuss/topic/76", external_url: "http://try.discourse.org")

        get "/admin/permalinks.json", params: { filter: "discourse" }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result.length).to eq(3)
      end
    end

    shared_examples "permalinks inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/permalinks.json", params: { filter: "topic" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "permalinks inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "permalinks inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "works for topics" do
        topic = Fabricate(:topic)

        post "/admin/permalinks.json",
             params: {
               permalink: {
                 url: "/topics/771",
                 permalink_type: "topic",
                 permalink_type_value: topic.id,
               },
             }

        expect(response.status).to eq(200)
        expect(Permalink.last).to have_attributes(
          url: "topics/771",
          topic_id: topic.id,
          post_id: nil,
          category_id: nil,
          tag_id: nil,
          external_url: nil,
          user_id: nil,
        )
      end

      it "works for posts" do
        some_post = Fabricate(:post)

        post "/admin/permalinks.json",
             params: {
               permalink: {
                 url: "/topics/771/8291",
                 permalink_type: "post",
                 permalink_type_value: some_post.id,
               },
             }

        expect(response.status).to eq(200)
        expect(Permalink.last).to have_attributes(
          url: "topics/771/8291",
          topic_id: nil,
          post_id: some_post.id,
          category_id: nil,
          tag_id: nil,
          external_url: nil,
          user_id: nil,
        )
      end

      it "works for categories" do
        category = Fabricate(:category)

        post "/admin/permalinks.json",
             params: {
               permalink: {
                 url: "/forums/11",
                 permalink_type: "category",
                 permalink_type_value: category.id,
               },
             }

        expect(response.status).to eq(200)
        expect(Permalink.last).to have_attributes(
          url: "forums/11",
          topic_id: nil,
          post_id: nil,
          category_id: category.id,
          tag_id: nil,
          external_url: nil,
          user_id: nil,
        )
      end

      it "works for tags" do
        tag = Fabricate(:tag)

        post "/admin/permalinks.json",
             params: {
               permalink: {
                 url: "/forums/12",
                 permalink_type: "tag",
                 permalink_type_value: tag.name,
               },
             }

        expect(response.status).to eq(200)
        expect(Permalink.last).to have_attributes(
          url: "forums/12",
          topic_id: nil,
          post_id: nil,
          category_id: nil,
          tag_id: tag.id,
          external_url: nil,
          user_id: nil,
        )
      end

      it "works for users" do
        user = Fabricate(:user)

        post "/admin/permalinks.json",
             params: {
               permalink: {
                 url: "/people/42",
                 permalink_type: "user",
                 permalink_type_value: user.id,
               },
             }

        expect(response.status).to eq(200)
        expect(Permalink.last).to have_attributes(
          url: "people/42",
          topic_id: nil,
          post_id: nil,
          category_id: nil,
          tag_id: nil,
          external_url: nil,
          user_id: user.id,
        )
      end
    end

    shared_examples "permalink creation not allowed" do
      it "prevents creation with a 404 response" do
        topic = Fabricate(:topic)

        expect do
          post "/admin/permalinks.json",
               params: {
                 permalink: {
                   url: "/topics/771",
                   permalink_type: "topic",
                   permalink_type_value: topic.id,
                 },
               }
        end.not_to change { Permalink.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "permalink creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "permalink creation not allowed"
    end
  end
end
