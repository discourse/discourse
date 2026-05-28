# frozen_string_literal: true

RSpec.describe PublishedPagesController do
  fab!(:published_page)
  fab!(:admin)
  fab!(:user)
  fab!(:user2, :user)

  context "when enabled" do
    before { SiteSetting.enable_page_publishing = true }

    context "when checking slug availability" do
      it "returns 403 for anonymous users" do
        get "/pub/check-slug.json?slug=cool-slug-man"
        expect(response.status).to eq(403)
      end

      it "returns 403 for regular users" do
        sign_in(user)
        get "/pub/check-slug.json?slug=cool-slug-man"
        expect(response.status).to eq(403)
      end

      context "as a staff member" do
        before { sign_in(admin) }

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
        fab!(:group)
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
          SiteSetting.logo_small = ""
          get published_page.path
          expect(response.body).to include(
            "<img class=\"published-page-logo\" src=\"#{SiteSetting.logo.url}\"/>",
          )

          SiteSetting.logo = ""
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

      describe "cache headers" do
        # Default fab!(:published_page) has public: false, so it's
        # never publicly cacheable. Use this fabricator for the cases
        # that exercise the cacheable branch.
        fab!(:public_page) do
          Fabricate(
            :published_page,
            public: true,
            slug: "public-cacheable-page",
            topic: Fabricate(:topic_with_op),
          )
        end

        it "sets a public Cache-Control header for anonymous visitors on a public page" do
          get public_page.path

          expect(response.status).to eq(200)
          expect(response.headers["Cache-Control"]).to include("public")
          expect(response.headers["Cache-Control"]).to include("s-maxage=0")
          expect(response.headers["Cache-Control"]).to include("must-revalidate")
          expect(response.headers["Cache-Control"]).not_to include("stale-while-revalidate")
          expect(response.headers["Vary"]).to eq("Accept, Accept-Encoding, Cookie, User-Agent")
          expect(response.headers["ETag"]).to be_present
        end

        it "sets a private Cache-Control header for authenticated visitors" do
          sign_in(user)
          get public_page.path

          expect(response.status).to eq(200)
          expect(response.headers["Cache-Control"]).to eq("private, no-store")
        end

        it "sets a private Cache-Control header on a non-public page" do
          get published_page.path

          # default fab has public: false; signed-out viewer would
          # normally see 403, but the default category isn't
          # restricted so this still returns 200 - the point is the
          # response must not be publicly cacheable.
          expect(response.headers["Cache-Control"]).to eq("private, no-store")
        end

        it "sets a private Cache-Control header when the source category is read-restricted" do
          group = Fabricate(:group)
          private_category = Fabricate(:private_category, group: group)
          public_page.topic.update!(category: private_category)

          get public_page.path

          expect(response.status).to eq(200)
          expect(response.headers["Cache-Control"]).to eq("private, no-store")
        end

        it "sets a private Cache-Control header when login is required for the site" do
          SiteSetting.login_required = true
          SiteSetting.show_published_pages_login_required = true

          get public_page.path

          expect(response.status).to eq(200)
          expect(response.headers["Cache-Control"]).to eq("private, no-store")
        end

        it "returns 304 Not Modified on a conditional GET with a matching ETag" do
          get public_page.path
          expect(response.status).to eq(200)
          etag = response.headers["ETag"]
          expect(etag).to be_present

          get public_page.path, headers: { "If-None-Match" => etag }
          expect(response.status).to eq(304)
        end

        it "returns a fresh 200 when the first post content changes without bumping the topic" do
          get public_page.path
          first_etag = response.headers["ETag"]
          first_bumped_at = public_page.topic.bumped_at

          freeze_time 1.minute.from_now do
            PostRevisor.new(public_page.topic.first_post, public_page.topic).revise!(
              admin,
              raw: "This public page content was edited without bumping the topic.",
            )
          end

          expect(public_page.topic.reload.bumped_at.to_i).to eq(first_bumped_at.to_i)

          get public_page.path, headers: { "If-None-Match" => first_etag }
          expect(response.status).to eq(200)
          expect(response.headers["ETag"]).not_to eq(first_etag)
        end

        it "returns a fresh 200 when the published page author changes" do
          get public_page.path
          first_etag = response.headers["ETag"]

          freeze_time 1.minute.from_now do
            public_page.topic.user.update!(username: "renamed_author")
          end

          get public_page.path, headers: { "If-None-Match" => first_etag }
          expect(response.status).to eq(200)
          expect(response.headers["ETag"]).not_to eq(first_etag)
          expect(response.body).to include("renamed_author")
        end

        it "returns a fresh 200 when rendered site settings change" do
          get public_page.path
          first_etag = response.headers["ETag"]

          freeze_time 1.minute.from_now do
            SiteSetting.title = "Renamed public site"
          end

          get public_page.path, headers: { "If-None-Match" => first_etag }
          expect(response.status).to eq(200)
          expect(response.headers["ETag"]).not_to eq(first_etag)
          expect(response.body).to include("Renamed public site")
        end

        it "returns a fresh 200 when the request switches to a mobile variant" do
          get public_page.path
          first_etag = response.headers["ETag"]

          get public_page.path,
              headers: {
                "HTTP_USER_AGENT" =>
                  "Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) Mobile/13D15",
                "If-None-Match" => first_etag,
              }

          expect(response.status).to eq(200)
          expect(response.headers["ETag"]).not_to eq(first_etag)
        end

        it "returns a fresh 200 when a theme cookie changes the rendered theme" do
          theme = Fabricate(:theme, user_selectable: true)
          theme.set_field(
            target: :common,
            name: "header",
            value: "cookie theme header",
            type: :html,
          )
          theme.save!

          get public_page.path
          first_etag = response.headers["ETag"]

          cookies["theme_ids"] = "#{theme.id}|0"
          get public_page.path, headers: { "If-None-Match" => first_etag }

          expect(response.status).to eq(200)
          expect(response.headers["ETag"]).not_to eq(first_etag)
          expect(response.body).to include("cookie theme header")
        end
      end
    end

    describe "publishing" do
      fab!(:topic)

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
