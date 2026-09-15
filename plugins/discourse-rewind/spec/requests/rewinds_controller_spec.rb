# frozen_string_literal: true

RSpec.describe DiscourseRewind::RewindsController do
  before { SiteSetting.discourse_rewind_enabled = true }

  describe "#dismiss" do
    it "requires login" do
      post "/rewinds/dismiss.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      fab!(:user)
      before { sign_in(user) }

      it "sets dismissed_at on user_option" do
        freeze_time DateTime.parse("2022-12-24 10:00:00")

        post "/rewinds/dismiss.json"

        expect(response.status).to eq(204)
        expect(user.user_option.reload.discourse_rewind_dismissed_at).to eq_time(Time.current)
      end

      it "returns dismissed state via session/current endpoint" do
        freeze_time DateTime.parse("2022-12-24")
        user.user_option.update!(discourse_rewind_dismissed_at: Time.current)

        get "/session/current.json"

        expect(
          response.parsed_body.dig("current_user", "user_option", "discourse_rewind_dismissed"),
        ).to eq(true)
      end
    end
  end

  describe "#index" do
    fab!(:user)

    before { sign_in(user) }

    context "when out of valid month" do
      before { freeze_time DateTime.parse("2022-11-24") }

      it "returns 404" do
        get "/rewinds.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("discourse_rewind.invalid_year"))
      end
    end

    context "when in valid month" do
      before { freeze_time DateTime.parse("2022-12-24") }

      it "returns 200 with reports and total_available" do
        get "/rewinds.json"

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body).to have_key("reports")
        expect(body).to have_key("total_available")
        expect(body["reports"].size).to be <= DiscourseRewind::FetchReports::INITIAL_REPORT_COUNT
        expect(body["total_available"]).to be >= body["reports"].size
      end

      context "when some reports fail" do
        before do
          DiscourseRewind::Action::TopWords.stubs(:call).raises(StandardError.new("Some error"))
        end

        it "returns reports excluding the failed ones" do
          get "/rewinds.json"

          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body["reports"]).to be_an(Array)
          expect(body["reports"].map { |r| r["identifier"] }).not_to include("top-words")
        end
      end
    end
  end

  describe "#show" do
    fab!(:user)

    before { sign_in(user) }

    context "when out of valid month" do
      before { freeze_time DateTime.parse("2022-11-24") }

      it "returns 404" do
        get "/rewinds/0.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("discourse_rewind.invalid_year"))
      end
    end

    context "when in valid month" do
      before { freeze_time DateTime.parse("2022-12-24") }

      it "does not return cached best post excerpts after their category becomes read-restricted" do
        report_user = Fabricate(:user)
        viewer = Fabricate(:user)
        category = Fabricate(:category)
        topic = Fabricate(:topic, category:, user: report_user)
        post =
          Fabricate(
            :post,
            topic:,
            user: report_user,
            post_number: 2,
            created_at: Time.zone.parse("2022-06-01"),
            raw: "classified rewind cache content",
            like_count: 1,
          )
        report_user.user_option.update!(discourse_rewind_share_publicly: true)

        sign_in(report_user)
        get "/rewinds/#{DiscourseRewind::FetchReports::REPORTS.index(DiscourseRewind::Action::BestPosts)}.json"

        expect(response.status).to eq(200)
        expect(response.body).to include(post.raw)

        category.update!(read_restricted: true)

        sign_in(viewer)
        get "/t/#{topic.id}.json"

        expect(response.status).to eq(404)
        expect(response.body).not_to include(post.raw)

        get "/rewinds/#{DiscourseRewind::FetchReports::REPORTS.index(DiscourseRewind::Action::BestPosts)}.json",
            params: {
              for_user_username: report_user.username,
            }

        expect(response.status).to eq(200)
        expect(response.body).not_to include(post.raw)
      end

      context "when reports are cached" do
        before { get "/rewinds.json" }

        it "returns 200 with the requested report" do
          get "/rewinds/0.json"

          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body).to have_key("report")
          expect(body["report"]).to have_key("identifier")
        end

        it "returns 404 for invalid index" do
          get "/rewinds/999.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.report_not_found"),
          )
        end
      end

      context "when cached topic-backed reports become ineligible" do
        fab!(:rewind_owner, :user)
        fab!(:viewer, :user)
        fab!(:restricted_category) { Fabricate(:category, read_restricted: true) }
        fab!(:unlisted_topic) do
          Fabricate(
            :topic,
            user: rewind_owner,
            created_at: DateTime.parse("2022-01-01"),
            title: "Cached unlisted topic title",
            excerpt: "Cached unlisted topic excerpt",
          )
        end
        fab!(:restricted_topic) do
          Fabricate(
            :topic,
            user: rewind_owner,
            created_at: DateTime.parse("2022-01-02"),
            title: "Cached restricted topic title",
          )
        end
        fab!(:eligible_topic) do
          Fabricate(
            :topic,
            user: rewind_owner,
            created_at: DateTime.parse("2022-01-03"),
            title: "Cached eligible topic title",
          )
        end
        fab!(:hidden_reply) do
          Fabricate(
            :post,
            topic: eligible_topic,
            user: rewind_owner,
            post_number: 2,
            created_at: DateTime.parse("2022-01-04"),
            raw: "Cached hidden post excerpt",
            like_count: 100,
          )
        end
        fab!(:deleted_reply) do
          Fabricate(
            :post,
            topic: eligible_topic,
            user: rewind_owner,
            post_number: 3,
            created_at: DateTime.parse("2022-01-05"),
            raw: "Cached deleted post excerpt",
            like_count: 99,
          )
        end
        fab!(:eligible_reply) do
          Fabricate(
            :post,
            topic: eligible_topic,
            user: rewind_owner,
            post_number: 4,
            created_at: DateTime.parse("2022-01-06"),
            raw: "Cached eligible post excerpt",
            like_count: 98,
          )
        end

        before do
          rewind_owner.user_option.update!(discourse_rewind_share_publicly: true)
          TopTopic.refresh!
          TopTopic.find_by!(topic_id: unlisted_topic.id).update!(yearly_score: 100)
          TopTopic.find_by!(topic_id: restricted_topic.id).update!(yearly_score: 99)
          TopTopic.find_by!(topic_id: eligible_topic.id).update!(yearly_score: 98)
          sign_in(rewind_owner)
          get "/rewinds/7.json"
          get "/rewinds/8.json"
        end

        it "omits an unlisted topic from a cached shared Best Topics report" do
          cached_report =
            DiscourseRewind::FetchReportsHelper.load_single_report_from_cache(
              rewind_owner.username,
              2022,
              "BestTopics",
            )
          cached_topic = cached_report[:data].find { |topic| topic[:topic_id] == unlisted_topic.id }
          expect(cached_topic).to be_present

          unlisted_topic.update!(visible: false)
          sign_in(viewer)

          get "/rewinds/7.json", params: { for_user_username: rewind_owner.username }

          expect(response.status).to eq(200)
          expect(
            response.parsed_body.dig("report", "data").map { |topic| topic["topic_id"] },
          ).to contain_exactly(restricted_topic.id, eligible_topic.id)
          expect(response.body).not_to include(cached_topic[:title])
          expect(response.body).not_to include(cached_topic[:excerpt])
          expect(
            DiscourseRewind::FetchReportsHelper.load_single_report_from_cache(
              rewind_owner.username,
              2022,
              "BestTopics",
            ),
          ).to include(data: include(cached_topic))
        end

        it "omits a deleted topic while retaining eligible cached Best Topics entries" do
          restricted_topic.trash!(Discourse.system_user)
          sign_in(viewer)

          get "/rewinds/7.json", params: { for_user_username: rewind_owner.username }

          expect(response.status).to eq(200)
          expect(
            response.parsed_body.dig("report", "data").map { |topic| topic["topic_id"] },
          ).to contain_exactly(unlisted_topic.id, eligible_topic.id)
        end

        it "omits a topic after the viewer loses category access while retaining eligible cached Best Topics entries" do
          restricted_topic.change_category_to_id(restricted_category.id)
          expect(viewer.guardian.can_see?(restricted_topic)).to eq(false)
          sign_in(viewer)

          get "/rewinds/7.json", params: { for_user_username: rewind_owner.username }

          expect(response.status).to eq(200)
          expect(
            response.parsed_body.dig("report", "data").map { |topic| topic["topic_id"] },
          ).to contain_exactly(unlisted_topic.id, eligible_topic.id)
        end

        it "omits hidden and deleted posts from a cached shared Best Posts report" do
          cached_report =
            DiscourseRewind::FetchReportsHelper.load_single_report_from_cache(
              rewind_owner.username,
              2022,
              "BestPosts",
            )
          cached_hidden_post =
            cached_report[:data].find { |post| post[:post_number] == hidden_reply.post_number }
          cached_deleted_post =
            cached_report[:data].find { |post| post[:post_number] == deleted_reply.post_number }
          expect(cached_hidden_post).to be_present
          expect(cached_deleted_post).to be_present

          hidden_reply.update!(hidden: true)
          deleted_reply.trash!(Discourse.system_user)
          sign_in(viewer)

          get "/rewinds/8.json", params: { for_user_username: rewind_owner.username }

          expect(response.status).to eq(200)
          expect(
            response.parsed_body.dig("report", "data").map { |post| post["post_number"] },
          ).to contain_exactly(eligible_reply.post_number)
          expect(response.body).not_to include(cached_hidden_post[:excerpt])
          expect(response.body).not_to include(cached_deleted_post[:excerpt])
        end
      end
    end
  end

  describe "#toggle_share" do
    it "requires login" do
      put "/rewinds/toggle-share.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      fab!(:user)
      before { sign_in(user) }

      it "toggles share preference from false to true" do
        user.user_option.update!(discourse_rewind_share_publicly: false)

        put "/rewinds/toggle-share.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["shared"]).to eq(true)
        expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(true)
      end

      it "toggles share preference from true to false" do
        user.user_option.update!(discourse_rewind_share_publicly: true)

        put "/rewinds/toggle-share.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["shared"]).to eq(false)
        expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
      end

      context "when user has hidden profile" do
        before { user.user_option.update!(hide_profile: true) }

        it "prevents enabling share when profile is hidden" do
          user.user_option.update!(discourse_rewind_share_publicly: false)

          put "/rewinds/toggle-share.json"

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.cannot_share_when_profile_hidden"),
          )
          expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
        end

        it "allows disabling share even when profile is hidden" do
          user.user_option.update!(discourse_rewind_share_publicly: true)

          put "/rewinds/toggle-share.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body["shared"]).to eq(false)
          expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
        end
      end
    end
  end
end
