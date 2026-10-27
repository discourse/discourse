# frozen_string_literal: true

RSpec.describe User::Silence do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_presence_of(:silenced_till) }
    it { is_expected.to validate_length_of(:reason).is_at_most(300) }

    it do
      is_expected.to validate_length_of(:other_user_ids).as_array.is_at_most(
        User::MAX_SIMILAR_USERS,
      )
    end

    it do
      is_expected.to validate_inclusion_of(:post_action).in_array(
        %w[delete delete_replies edit none],
      ).allow_blank
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)

    let(:params) { { user_id:, reason:, silenced_till:, other_user_ids:, message: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:user_id) { user.id }
    let(:other_user_ids) { other_user.id }
    let(:reason) { "spam" }
    let(:message) { "it was spam" }
    let(:silenced_till) { 3.hours.from_now.to_s }

    context "when invalid data is provided" do
      let(:user_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when provided user does not exist" do
      let(:user_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when user is already silenced" do
      before { UserSilencer.silence(user, admin) }

      it { is_expected.to fail_a_policy(:not_silenced_already) }
    end

    context "when all users cannot be silenced" do
      let(:other_user_ids) { [other_user.id, Fabricate(:admin).id].join(",") }

      it { is_expected.to fail_a_policy(:can_silence_all_users) }
    end

    context "when the user is an anonymous shadow" do
      fab!(:shadow) do
        Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: user) }
      end

      let(:user_id) { shadow.id }

      before { SiteSetting.allow_anonymous_mode = true }

      it "silences the account behind the shadow and messages the shadow" do
        result

        expect(user.reload).to be_silenced
        expect(Topic.private_messages_for_user(shadow)).to exist
        expect(Topic.private_messages_for_user(user)).to be_empty
      end
    end

    context "when everything's ok" do
      it "silences all provided users" do
        result
        expect([user, other_user].map(&:reload)).to all be_silenced
      end

      it "uses the recipient’s personal message email preference for a timed silence" do
        NotificationEmailer.enable
        user.user_option.update!(
          timezone: "Asia/Kolkata",
          email_messages_level: UserOption.email_level_types[:always],
        )
        other_user.user_option.update!(email_messages_level: UserOption.email_level_types[:never])
        params[:silenced_till] = Time.iso8601("2028-01-15T12:00:00Z")

        result

        [user, other_user].each do |recipient|
          topic = Topic.private_messages_for_user(recipient).sole
          expect(topic.title).to eq("Your account has been silenced")
          expect(topic.first_post.raw).to include("Reason: spam\n\nit was spam")
        end
        expect(Topic.private_messages_for_user(user).sole.first_post.raw).to include(
          "5:30pm (UTC+05:30)",
        )

        Jobs::PostAlert.drain
        emails = Jobs::UserEmail.jobs.map { |job| job["args"].first }
        expect(emails).to contain_exactly(
          include("type" => "user_private_message", "user_id" => user.id),
        )
        expect(Jobs::CriticalUserEmail.jobs).to be_empty
      end

      it "includes the reason and appeal instructions in an indefinite silence notice" do
        TranslationOverride.upsert!(
          :en,
          "system_messages.silenced_by_staff.text_body_template",
          "Waiting for staff review.",
        )
        params.merge!(other_user_ids: [], silenced_till: 101.years.from_now)
        enable_dsa_reporting
        SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"

        result

        notice = Topic.private_messages_for_user(user).sole.first_post
        expect(notice.raw).to include(
          "This is an automated message from #{SiteSetting.title} to let you know that a moderator silenced your account indefinitely.",
          reason,
          message,
          "appeals@example.com",
        )
      end

      it "exposes the full reason in the result object" do
        expect(result[:full_reason]).to eq("spam\n\nit was spam")
      end

      it "deletes the selected post" do
        post = Fabricate(:post, user:)
        params.merge!(post_id: post.id, post_action: "delete")

        result

        expect(post.reload).to be_trashed
      end

      it "ignores a post authored by someone other than the silenced users" do
        post = Fabricate(:post)
        params.merge!(post_id: post.id, post_action: "delete")

        result

        expect(post.reload).not_to be_trashed
      end
    end
  end
end
