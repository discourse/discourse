# frozen_string_literal: true

describe "User invites" do
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

  describe "pending invites" do
    let(:user_invite_pending_page) { PageObjects::Pages::UserInvitedPending.new }
    let(:cdp) { PageObjects::CDP.new }

    it "can load more invites" do
      SiteSetting.invites_per_page = 3

      user_invite_pending_page.visit(user)

      expect(user_invite_pending_page).to have_invite_count(invites_pending.size)
    end

    it "lets the user copy an invite's link from its actions menu" do
      invite = Fabricate(:invite, invited_by: user, email: "copy-me@example.com")
      cdp.allow_clipboard

      user_invite_pending_page.visit(user)
      invite_row = user_invite_pending_page.invite_row(invite)
      invite_row.copy_link

      expect(invite_row).to have_link_copied
      cdp.clipboard_has_text?(invite.link)
    end
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
