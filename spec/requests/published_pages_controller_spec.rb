# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublishedPagesController do
  fab!(:published_page) { Fabricate(:published_page) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  context "when enabled" do
    before do
      SiteSetting.enable_page_publishing = true
    end

    context "check slug availability" do
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

    context "show" do
      it "returns 404 for a missing article" do
        get "/pub/no-article-here-no-thx"
        expect(response.status).to eq(404)
      end

      context "private topic" do
        fab!(:group) { Fabricate(:group) }
        fab!(:private_category) { Fabricate(:private_category, group: group) }

        before do
          published_page.topic.update!(category: private_category)
        end

        it "returns 403 for a topic you can't see" do
          get published_page.path
          expect(response.status).to eq(403)
        end

        context "published page is public" do
          fab!(:public_published_page) {
            Fabricate(:published_page, public: true, slug: "a-public-page")
          }

          it "returns 200 for a topic you can't see" do
            get public_published_page.path
            expect(response.status).to eq(200)
          end
        end

        context "as an admin" do
          before do
            sign_in(admin)
          end

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

      context "the article is valid" do
        before do
          SiteSetting.tagging_enabled = true
          published_page.topic.tags = [Fabricate(:tag, name: "recipes")]
        end

        it "returns 200" do
          get published_page.path
          expect(response.status).to eq(200)
        end

        it "defines correct css classes on body" do
          get published_page.path
          expect(response.body).to include("<body class=\"published-page #{published_page.slug} topic-#{published_page.topic_id} recipes uncategorized\">")
        end

        context "login is required" do
          before do
            SiteSetting.login_required = true
            SiteSetting.show_published_pages_login_required = false
          end

          context "a user is connected" do
            before do
              sign_in(user)
            end

            it "returns 200" do
              get published_page.path
              expect(response.status).to eq(200)
            end
          end

          context "no user connected" do
            it "redirects to login page" do
              expect(get(published_page.path)).to redirect_to("/login")
            end

            context "show public pages with login required is enabled" do
              before do
                SiteSetting.show_published_pages_login_required = true
              end

              it "returns 200" do
                get published_page.path
                expect(response.status).to eq(200)
              end
            end
          end
        end
      end
    end

    context "publishing" do
      fab!(:topic) { Fabricate(:topic) }

      it "returns invalid access for non-staff" do
        sign_in(user)
        put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: 'cant-do-this' } }
        expect(response.status).to eq(403)
      end

      context "with a valid staff account" do
        before do
          sign_in(admin)
        end

        it "creates the published page record" do
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: 'i-hate-salt' } }
          expect(response).to be_successful
          expect(response.parsed_body['published_page']).to be_present
          expect(response.parsed_body['published_page']['slug']).to eq("i-hate-salt")
          expect(response.parsed_body['published_page']['public']).to eq(false)

          expect(PublishedPage.exists?(topic_id: response.parsed_body['published_page']['id'])).to eq(true)
          expect(UserHistory.exists?(
            acting_user_id: admin.id,
            action: UserHistory.actions[:page_published],
            topic_id: topic.id
          )).to be(true)
        end

        it "allows to set public field" do
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: 'i-hate-salt', public: true } }
          expect(response).to be_successful
          expect(response.parsed_body['published_page']).to be_present
          expect(response.parsed_body['published_page']['slug']).to eq("i-hate-salt")
          expect(response.parsed_body['published_page']['public']).to eq(true)

          expect(PublishedPage.exists?(topic_id: response.parsed_body['published_page']['id'])).to eq(true)
        end

        it "returns an error if the slug is already taken" do
          PublishedPage.create!(slug: 'i-hate-salt', topic: Fabricate(:topic))
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: 'i-hate-salt' } }
          expect(response).not_to be_successful
          expect(response.parsed_body['errors']).to eq(['Slug has already been taken'])
        end

        it "returns an error if the topic already has been published" do
          PublishedPage.create!(slug: 'already-done-pal', topic: topic)
          put "/pub/by-topic/#{topic.id}.json", params: { published_page: { slug: 'i-hate-salt' } }
          expect(response).to be_successful
          expect(PublishedPage.exists?(topic_id: topic.id)).to eq(true)
        end

      end
    end

    context "destroy" do

      it "returns invalid access for non-staff" do
        sign_in(user)
        delete "/pub/by-topic/#{published_page.topic_id}.json"
        expect(response.status).to eq(403)
      end

      context "with a valid staff account" do
        before do
          sign_in(admin)
        end

        it "deletes the record" do
          topic_id = published_page.topic_id

          delete "/pub/by-topic/#{topic_id}.json"
          expect(response).to be_successful
          expect(PublishedPage.exists?(slug: published_page.slug)).to eq(false)

          expect(UserHistory.exists?(
            acting_user_id: admin.id,
            action: UserHistory.actions[:page_unpublished],
            topic_id: topic_id
          )).to be(true)
        end
      end
    end
  end

  context "when disabled" do
    before do
      SiteSetting.enable_page_publishing = false
    end

    it "returns 404 for any article" do
      get published_page.path
      expect(response.status).to eq(404)
    end
  end

end
