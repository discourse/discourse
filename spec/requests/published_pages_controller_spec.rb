# frozen_string_literal: true

RSpec.describe PublishedPagesController do
  fab!(:published_page) { Fabricate(:published_page) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  context "when enabled" do
    before { SiteSetting.enable_page_publishing = true }

    context "when checking slug availability" do
      it "returns true for a new slug" do
        get "/pub/check-slug.json?slug=cool-slug-man"
        expect(response).to be_successful
        expect(response.parsed_body["valid_slug"]).to eq(true)
      end

      it "returns true for a new slug with whitespace" do
        get "/pub/check-slug.json?slug=cool-slug-man%20"
        expect(response).to be_successful
        expect(response.parsed_body["valid_slug"]).to eq(true)
      end

      it "returns false for an empty value" do
        get "/pub/check-slug.json?slug="
        expect(response).to be_successful
        expect(response.parsed_body["valid_slug"]).to eq(false)
        expect(response.parsed_body["reason"]).to be_present
      end

      it "returns false for a reserved value" do
        get "/pub/check-slug.json", params: { slug: "check-slug" }
        expect(response).to be_successful
        expect(response.parsed_body["valid_slug"]).to eq(false)
        expect(response.parsed_body["reason"]).to be_present
      end
    end

    describe "#show" do
      it "records a view" do
        sign_in(user2)
        expect do get published_page.path end.to change(TopicViewItem, :count).by(1)
      end

      it "returns 404 for a missing article" do
        get "/pub/no-article-here-no-thx"
        expect(response.status).to eq(404)
      end

      context "with private topic" do
        fab!(:group) { Fabricate(:group) }
        fab!(:private_category) { Fabricate(:private_category, group: group) }

        before { published_page.topic.update!(category: private_category) }

        it "returns 403 for a topic you can't see" do
          get published_page.path
          expect(response.status).to eq(403)
        end

        context "when published page is public" do
          fab!(:public_published_page) do
            Fabricate(:published_page, public: true, slug: "a-public-page")
          end

          it "returns 200 for a topic you can't see" do
            get public_published_page.path
            expect(response.status).to eq(200)
          end
        end

        context "as an admin" do
          before { sign_in(admin) }

          it "returns 200" do
            get published_page.path
            expect(response.status).to eq(200)
          end
        end
      end

      it "returns an error for an article you can't see" do
        get "/pub/no-article-here-no-thx"
        expect(response.status).to eq(404)
      end

      context "when the article is valid" do
        before do
          SiteSetting.tagging_enabled = true
          published_page.topic.tags = [Fabricate(:tag, name: "recipes")]
        end

        context "when secure uploads is enabled" do
          before do
            setup_s3
            SiteSetting.secure_uploads = true
          end

          it "returns 404" do
            get published_page.path
            expect(response.status).to eq(404)
          end
        end

        it "returns 200" do
          get published_page.path
          expect(response.status).to eq(200)
        end

        it "works even if image logos are not available" do
          SiteSetting.logo_small = nil
          get published_page.path
          expect(response.body).to include(
            "<img class=\"published-page-logo\" src=\"#{SiteSetting.logo.url}\"/>",
          )

          SiteSetting.logo = nil
          get published_page.path
          expect(response.body).not_to include("published-page-logo")
        end

        it "defines correct css classes on body" do
          get published_page.path
          expect(response.body).to include(
            "<body class=\"published-page #{published_page.slug} topic-#{published_page.topic_id} recipes uncategorized\">",
          )
        end

        context "when login is required" do
          before do
            SiteSetting.login_required = true
            SiteSetting.show_published_pages_login_required = false
          end

          context "when a user is connected" do
            before { sign_in(user) }

            it "returns 200" do
              get published_page.path
              expect(response.status).to eq(200)
            end
          end

          context "with no user connected" do
            it "redirects to login page" do
              expect(get(published_page.path)).to redirect_to("/login")
            end

            context "when login required is enabled" do
              before { SiteSetting.show_published_pages_login_required = true }

              it "returns 200" do
                get published_page.path
                expect(response.status).to eq(200)
              end
            end
          end
        end
      end
    end

    describe "publishing" do
      fab!(:topic) { Fabricate(:topic) }

      it "returns invalid access for non-staff" do
        sign_in(user)
        put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: "cant-do-this" } }
        expect(response.status).to eq(403)
      end

      context "with a valid staff account" do
        before { sign_in(admin) }

        it "creates the published page record" do
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: "i-hate-salt" } }
          expect(response).to be_successful
          expect(response.parsed_body["published_page"]).to be_present
          expect(response.parsed_body["published_page"]["slug"]).to eq("i-hate-salt")
          expect(response.parsed_body["published_page"]["public"]).to eq(false)

          expect(
            PublishedPage.exists?(topic_id: response.parsed_body["published_page"]["id"]),
          ).to eq(true)
          expect(
            UserHistory.exists?(
              acting_user_id: admin.id,
              action: UserHistory.actions[:page_published],
              topic_id: topic.id,
            ),
          ).to be(true)
        end

        it "allows to set public field" do
          put "/pub/by-topic/#{topic.id}.json",
              params: {
                published_page: {
                  slug: "i-hate-salt",
                  public: true,
                },
              }
          expect(response).to be_successful
          expect(response.parsed_body["published_page"]).to be_present
          expect(response.parsed_body["published_page"]["slug"]).to eq("i-hate-salt")
          expect(response.parsed_body["published_page"]["public"]).to eq(true)

          expect(
            PublishedPage.exists?(topic_id: response.parsed_body["published_page"]["id"]),
          ).to eq(true)
        end

        it "returns an error if the slug is already taken" do
          PublishedPage.create!(slug: "i-hate-salt", topic: Fabricate(:topic))
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: "i-hate-salt" } }
          expect(response).not_to be_successful
          expect(response.parsed_body["errors"]).to eq(["Slug has already been taken"])
        end

        it "returns an error if the topic already has been published" do
          PublishedPage.create!(slug: "already-done-pal", topic: topic)
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: "i-hate-salt" } }
          expect(response).to be_successful
          expect(PublishedPage.exists?(topic_id: topic.id)).to eq(true)
        end
      end
    end

    describe "#destroy" do
      it "returns invalid access for non-staff" do
        sign_in(user)
        delete "/pub/by-topic/#{published_page.topic_id}.json"
        expect(response.status).to eq(403)
      end

      context "with a valid staff account" do
        before { sign_in(admin) }

        it "deletes the record" do
          topic_id = published_page.topic_id

          delete "/pub/by-topic/#{topic_id}.json"
          expect(response).to be_successful
          expect(PublishedPage.exists?(slug: published_page.slug)).to eq(false)

          expect(
            UserHistory.exists?(
              acting_user_id: admin.id,
              action: UserHistory.actions[:page_unpublished],
              topic_id: topic_id,
            ),
          ).to be(true)
        end
      end
    end
  end

  context "when disabled" do
    before { SiteSetting.enable_page_publishing = false }

    it "returns 404 for any article" do
      get published_page.path
      expect(response.status).to eq(404)
    end
  end
end
