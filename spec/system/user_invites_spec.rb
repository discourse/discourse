# frozen_string_literal: true

describe "User Invites", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:invite) { Fabricate(:invite, email: nil, domain: nil, max_redemptions_allowed: 1) }
  fab!(:invited_group) { Fabricate(:invited_group, invite: invite) }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  it "can redeem invite as existing user and not have invited_by" do
    sign_in(user)
    visit "/invites/#{invite.invite_key}"

    assert_selector(".invite-page .login-welcome-header")
    assert_selector(".invite-form", text: "You were invited by:")
    assert_selector(".invite-form .user-detail .name-line", text: invite.invited_by.username)

    find(".invite-form .btn-primary").click
    expect(page).to have_current_path("/")

    sign_in(admin)
    visit "/u/#{user.username}/summary"
    expect(page).not_to have_css(".invited-by")
  end

  it "includes invited_by user in the invitee's summary" do
    visit "/invites/#{invite.invite_key}"
    assert_selector(".invite-form .user-detail .name-line", text: invite.invited_by.username)

    fill_in "Email", with: "boaty@mcboatface.com"
    fill_in "Password", with: "boatyMcBoatface"
    fill_in "Username", with: "boaty"
    find(".invitation-cta__accept:not([disabled])", wait: 10)

    assert_selector(".login-title", text: "Welcome to Discourse!")

    find(".invite-form .btn-primary").click
    wait_for { User.find_by_username("boaty").present? }

    User.find_by_username("boaty").activate

    sign_in(admin)
    visit "/u/boaty/summary"
    assert_selector("dt.invited-by", text: "Invited By")
    assert_selector("dd.invited-by", text: invite.invited_by.username)
  end
end
