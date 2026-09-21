# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Invites do
  fab!(:user)

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
