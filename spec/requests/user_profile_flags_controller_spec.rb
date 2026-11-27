# frozen_string_literal: true

RSpec.describe UserProfileFlagsController do
  fab!(:reporter) { Fabricate(:trust_level_1, refresh_auto_groups: true) }
  fab!(:target) { Fabricate(:user, approved: true) }

  describe "#create" do
    let(:spam) { PostActionType.types[:spam] }
    let(:path) { "/u/#{target.username}/profile-flags.json" }

    before do
      SiteSetting.hide_new_user_profiles = false
      SiteSetting.flaggable_user_profiles = true
    end

    it "requires a signed-in reporter even when visitors can report illegal content" do
      enable_dsa_reporting
      post path,
           params: {
             flag_type_id: PostActionType.types[:illegal],
             message: "Illegal content in this biography",
             confirmed: true,
           }
      expect(response).to have_http_status(:forbidden)
      expect(ReviewableFlaggedProfile.count).to eq(0)
    end

    it "only offers guest reporting when anonymous visitors are in the rollout" do
      SiteSetting.contact_email = "legal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      audience =
        Fabricate(
          :site_setting_group,
          name: :flaggable_user_profiles,
          group_ids: Group::AUTO_GROUPS[:logged_in_users].to_s,
        )

      get "/u/#{target.username}.json"
      expect(response.parsed_body.fetch("user")).to include(
        "available_profile_flag_ids" => [],
        "can_report_profile_by_email" => false,
        "can_submit_profile_dsa_notice" => false,
      )

      enable_dsa_reporting
      get "/u/#{target.username}.json"
      expect(response.parsed_body.dig("user", "can_submit_profile_dsa_notice")).to be(false)

      audience.update!(group_ids: Group::AUTO_GROUPS[:anonymous_users].to_s)
      SiteSetting.refresh_site_setting_group_ids!
      get "/u/#{target.username}.json"
      expect(response.parsed_body.fetch("user")).to include(
        "available_profile_flag_ids" => [],
        "can_report_profile_by_email" => false,
        "can_submit_profile_dsa_notice" => true,
      )

      SiteSetting.allow_users_to_hide_profile = true
      target.user_option.update!(hide_profile: true)
      get "/u/#{target.username}.json"
      expect(response.parsed_body.fetch("user")).to include("profile_hidden" => true)
      expect(response.parsed_body.fetch("user")).not_to include(
        "can_report_profile_by_email",
        "can_submit_profile_dsa_notice",
      )
    end

    it "offers anonymous illegal-content reporting on visible staff profiles when ordinary staff flags are disabled" do
      moderator = Fabricate(:moderator)
      SiteSetting.allow_flagging_staff = false
      SiteSetting.contact_email = "legal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true

      get "/u/#{moderator.username}.json"
      expect(response.parsed_body.fetch("user")).to include(
        "available_profile_flag_ids" => [],
        "can_report_profile_by_email" => true,
        "can_submit_profile_dsa_notice" => false,
      )

      SiteSetting.allow_all_users_to_flag_illegal_content = false
      enable_dsa_reporting
      get "/u/#{moderator.username}.json"
      expect(response.parsed_body.fetch("user")).to include(
        "available_profile_flag_ids" => [],
        "can_report_profile_by_email" => false,
        "can_submit_profile_dsa_notice" => true,
      )
    end

    context "when signed in" do
      before { sign_in(reporter) }

      it "only offers and accepts reports from the rollout cohort" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: :flaggable_user_profiles, group_ids: group.id.to_s)

        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to be_blank
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)

        group.add(reporter)
        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to include(spam)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)

        SiteSetting.flaggable_user_profiles = false
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)
      end

      it "requires a visible profile, a different user, and flagging privileges" do
        post "/u/#{reporter.username}/profile-flags.json", params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)

        SiteSetting.allow_users_to_hide_profile = true
        target.user_option.update!(hide_profile: true)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)

        target.user_option.update!(hide_profile: false)
        SiteSetting.flag_post_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)
        expect(ReviewableFlaggedProfile.count).to eq(0)
      end

      it "checks staff-target and silencing restrictions" do
        moderator = Fabricate(:moderator)
        SiteSetting.allow_flagging_staff = false
        post "/u/#{moderator.username}/profile-flags.json", params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)

        reporter.update!(silenced_till: 1.day.from_now)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:not_found)
      end

      it "requires an enabled profile flag and validates its explanation" do
        message_flag = PostActionType.types[:notify_moderators]
        [PostActionType.types[:off_topic], PostActionType.types[:like]].each do |id|
          post path, params: { flag_type_id: id }
          expect(response).to have_http_status(:bad_request)
        end
        Flag.find(spam).update!(enabled: false)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:bad_request)

        ["  ", "a" * 501].each do |message|
          post path, params: { flag_type_id: message_flag, message: }
          expect(response.status).to be_between(400, 499)
        end
        expect(ReviewableFlaggedProfile.count).to eq(0)
      end

      it "groups reports, preserves the first profile snapshot, and exposes them for moderation" do
        target.user_profile.update!(bio_raw: "Original biography")
        message = "Please review the link in this biography."
        params = { flag_type_id: PostActionType.types[:notify_moderators], message: }
        post(path, params:)
        expect(response).to have_http_status(:created)
        score_id = response.parsed_body.dig("profile_flag", "id")

        post(path, params:)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("profile_flag", "id")).to eq(score_id)
        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to be_blank

        target.user_profile.update!(bio_raw: "Edited biography")
        sign_in(Fabricate(:trust_level_1, refresh_auto_groups: true))
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        reviewable = ReviewableFlaggedProfile.sole
        expect(reviewable.reviewable_scores.count).to eq(2)
        expect(reviewable.payload["bio"]).to eq("Original biography")

        moderator = Fabricate(:moderator)
        sign_in(moderator)
        get "/review.json", params: { type: "ReviewableFlaggedProfile" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.fetch("reviewables").sole).to include(
          "target_url" => target.relative_url,
          "created_from_flag" => true,
        )
        expect(response.parsed_body.fetch("reviewable_scores")).to include(
          a_hash_including("id" => score_id, "reason" => message),
        )
        SiteSetting.flaggable_user_profiles = false
        reviewable.perform(moderator, :dismiss_profile_flag)
        expect(reviewable.reload).to be_rejected
        expect(reporter.user_stat.reload.flags_disagreed).to eq(1)

        SiteSetting.flaggable_user_profiles = true
        sign_in(reporter)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        expect(reviewable.reload.payload["bio"]).to eq("Edited biography")
        reviewable.perform(moderator, :agree_profile_flag)
        expect(reviewable.reload).to be_approved
      end

      it "captures only anonymized details when a profile is flagged again before background cleanup" do
        Jobs.run_later!
        previous_username = target.username
        public_field = Fabricate(:user_field, show_on_profile: true)
        target.set_user_field(public_field.id, "Former public profile detail")
        target.save_custom_fields
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        report = ReviewableFlaggedProfile.sole
        expect(report.payload.fetch("profile_fields")).to contain_exactly(
          { "name" => public_field.name, "value" => "Former public profile detail" },
        )

        UserAnonymizer.make_anonymous(target, Fabricate(:admin))
        expect(target.reload.username).not_to eq(previous_username)
        expect(report.reload).to be_ignored
        post "/u/#{target.username}/profile-flags.json", params: { flag_type_id: spam }

        expect(response).to have_http_status(:created)
        expect(report.reload).to be_pending
        expect(report.payload.fetch("username")).to eq(target.username)
        expect(report.payload["profile_fields"]).to be_blank
      end

      it "accepts only a confirmed illegal flag from members with the illegal-only permission" do
        SiteSetting.contact_email = "contact@example.com"
        SiteSetting.allow_all_users_to_flag_illegal_content = true
        reporter.update!(silenced_till: 1.day.from_now)
        illegal = PostActionType.types[:illegal]
        message = "The offer in this biography appears to be illegal."

        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to eq([illegal])
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:bad_request)
        post path, params: { flag_type_id: illegal, message: }
        expect(response).to have_http_status(:bad_request)
        post path, params: { flag_type_id: illegal, confirmed: true }
        expect(response).to have_http_status(:bad_request)
        expect(ReviewableFlaggedProfile.count).to eq(0)

        post path, params: { flag_type_id: illegal, message:, confirmed: true }
        expect(response).to have_http_status(:created)
        reviewable = ReviewableFlaggedProfile.sole
        expect(reviewable).to be_potentially_illegal
        expect(reviewable.reviewable_scores.sole).to have_attributes(
          reviewable_score_type: illegal,
          context: message,
        )
      end

      it "offers the dedicated DSA form in the rollout and rejects ordinary illegal flags when DSA is enabled" do
        enable_dsa_reporting
        illegal = PostActionType.types[:illegal]
        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "can_submit_profile_dsa_notice")).to be(true)
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to contain_exactly(
          spam,
          PostActionType.types[:inappropriate],
          PostActionType.types[:notify_moderators],
        )
        post path,
             params: {
               flag_type_id: illegal,
               message: "Please review this profile.",
               confirmed: true,
             }
        expect(response).to have_http_status(:bad_request)
        expect(ReviewableFlaggedProfile.count).to eq(0)

        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "available_profile_flag_ids")).to be_empty
        expect(response.parsed_body.dig("user", "can_submit_profile_dsa_notice")).to be(true)

        SiteSetting.flaggable_user_profiles = false
        get "/u/#{target.username}.json"
        expect(response.parsed_body.dig("user", "can_submit_profile_dsa_notice")).to be(false)
      end

      it "requires DSA classification for a new spam report after an illegal flag was dismissed" do
        moderator = Fabricate(:moderator)
        post path,
             params: {
               flag_type_id: PostActionType.types[:illegal],
               message: "Please review this profile.",
               confirmed: true,
             }
        expect(response).to have_http_status(:created)
        reviewable = ReviewableFlaggedProfile.sole

        sign_in(Fabricate(:trust_level_1, refresh_auto_groups: true))
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        expect(reviewable.reload).to be_potentially_illegal
        reviewable.perform(moderator, :dismiss_profile_flag)

        enable_dsa_reporting
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        expect(reviewable.reload).not_to be_potentially_illegal
        action =
          reviewable
            .actions_for(moderator.guardian)
            .to_a
            .find { |candidate| candidate.server_action == "remove_profile_content" }
        expect(action.dsa_classification_required).to be(true)
      end

      it "expires the report independently of the approved account and its signup review" do
        signup = ReviewableUser.create_for(target)
        signup.transition_to(:approved, Discourse.system_user)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        reviewable = ReviewableFlaggedProfile.sole
        reviewable.update_column(:created_at, 61.days.ago)
        SiteSetting.auto_handle_queued_age = 60
        SiteSetting.flaggable_user_profiles = false

        Jobs::AutoQueueHandler.new.execute({})

        expect(reviewable.reload).to be_ignored
        expect(reviewable.reviewable_scores.sole).to have_attributes(
          status: "ignored",
          reviewed_by_id: Discourse::SYSTEM_USER_ID,
        )
        expect(target.reload).to be_approved
        expect(signup.reload).to be_approved
        expect(target.posts).to be_empty
      end

      it "accepts a custom profile flag and snapshots only fields displayed on the profile" do
        flag = Fabricate(:flag, applies_to: ["UserProfile"], require_message: true)
        header = Fabricate(:upload)
        target.user_profile.update!(profile_background_upload: header)
        public_field = Fabricate(:user_field, show_on_profile: true)
        private_field = Fabricate(:user_field, show_on_profile: false)
        target.set_user_field(public_field.id, "Public information")
        target.set_user_field(private_field.id, "Private information")
        target.save_custom_fields

        message = "Please review the <text> in the profile field."
        post path, params: { flag_type_id: flag.id, message: }
        expect(response).to have_http_status(:created)
        reviewable = ReviewableFlaggedProfile.sole
        expect(UploadReference.exists?(target: reviewable, upload: header)).to be(true)
        expect(reviewable.payload["profile_fields"]).to contain_exactly(
          { "name" => public_field.name, "value" => "Public information" },
        )
        score = reviewable.reviewable_scores.sole
        expect(ReviewableScoreSerializer.new(score, scope: reporter.guardian).reason).to eq(
          ERB::Util.html_escape(message),
        )
      end

      it "applies the shared daily flag limit once per new report" do
        RateLimiter.enable
        SiteSetting.max_flags_per_day = 1
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:created)
        post path, params: { flag_type_id: spam }
        expect(response).to have_http_status(:ok)

        other_target = Fabricate(:user)
        post "/u/#{other_target.username}/profile-flags.json", params: { flag_type_id: spam }
        expect(response).to have_http_status(:too_many_requests)
        expect(ReviewableFlaggedProfile.count).to eq(1)
      end
    end
  end
end
