# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Invites do
  fab!(:user)

  describe ".call" do
    it "returns nothing when there are too few invites to show" do
      Fabricate(:invite, invited_by: user, created_at: random_datetime)

      expect(call_report).to be_nil
    end

    it "returns the invite statistics" do
      busy_invitee, quiet_invitee = Fabricate.times(2, :user)
      redeemed_invite =
        Fabricate(:invite, invited_by: user, redemption_count: 1, created_at: random_datetime)
      Fabricate(:invite, invited_by: user, created_at: random_datetime)
      [busy_invitee, quiet_invitee].each do |invitee|
        Fabricate(:invited_user, invite: redeemed_invite, user: invitee, redeemed_at: Time.current)
      end
      4.times { Fabricate(:post, user: busy_invitee, created_at: random_datetime) }
      liked_post = Fabricate(:post, user: quiet_invitee, created_at: random_datetime)
      [quiet_invitee, user].each do |author|
        Fabricate(:topic, user: author, created_at: random_datetime)
      end
      [UserAction::LIKE, UserAction::WAS_LIKED].each do |action_type|
        Fabricate(
          :user_action,
          action_type:,
          user: quiet_invitee,
          target_post: liked_post,
          target_topic: liked_post.topic,
          created_at: random_datetime,
        )
      end

      expect(call_report[:data]).to eq(
        total_invites: 2,
        redeemed_count: 1,
        redemption_rate: 50.0,
        invitee_post_count: 5,
        invitee_topic_count: 1,
        invitee_like_count: 1,
        most_active_invitee: BasicUserSerializer.new(busy_invitee, root: false).as_json,
      )
    end
  end

  describe ".filter_for_viewer" do
    let(:report) { { data: { total_invites: 1 } } }

    it "hides the invites from other users" do
      expect(
        described_class.filter_for_viewer(
          report,
          guardian: Fabricate(:user).guardian,
          for_user: user,
        ),
      ).to be_nil
    end

    it "shows the invites to the owner and staff" do
      [user, Fabricate(:moderator)].each do |viewer|
        expect(
          described_class.filter_for_viewer(report, guardian: viewer.guardian, for_user: user),
        ).to eq(report)
      end
    end
  end
end
