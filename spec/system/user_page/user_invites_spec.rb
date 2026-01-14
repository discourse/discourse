# frozen_string_literal: true

describe "User invites", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:invites_pending) { [1, 2, 3, 4].map { Fabricate(:invite, invited_by: user) } }
  fab!(:invites_expired) do
    [1, 2, 3].map { Fabricate(:invite, invited_by: user, expires_at: 2.days.ago) }
  end

  before do
    SiteSetting.invite_expiry_days = 1
    sign_in(admin)
  end

  describe "expired invites" do
    let(:user_invite_expired_page) { PageObjects::Pages::UserInvitedExpired.new }
    it "correctly shows expired invites" do
      user_invite_expired_page.visit(user)
      expect(user_invite_expired_page.invites_list.size).to eq(invites_expired.size)
    end

    it "can remove all expired invites" do
      user_invite_expired_page.visit(user)
      user_invite_expired_page.bulk_remove_expired_button.click
      user_invite_expired_page.find(".btn-danger").click
      user_invite_expired_page.wait_till_loaded

      expect(user_invite_expired_page).to be_empty
      invites_expired.each { |invite| expect(invite.reload.deleted_at).to be_present }
    end
  end
end
