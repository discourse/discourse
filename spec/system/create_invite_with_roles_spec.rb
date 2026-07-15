# frozen_string_literal: true

describe "Creating invites with roles" do
  include ThemeScreenshotMarker

  fab!(:admin)
  fab!(:group)
  fab!(:user) { Fabricate(:user, groups: [group]) }

  let(:user_invited_pending_page) { PageObjects::Pages::UserInvitedPending.new }
  let(:modal) { PageObjects::Modals::CreateInviteWithRoles.new }
  let(:invite_form) { PageObjects::Pages::InviteForm.new }
  let(:cdp) { PageObjects::CDP.new }

  before { SiteSetting.enable_admin_invites = true }

  def open_invite_modal_for(current_user)
    user_invited_pending_page.visit(current_user)
    find(".user-invite-buttons .btn", match: :first).click
  end

  context "when signed in as an admin" do
    fab!(:placeholder_invite) do
      Fabricate(:invite, invited_by: admin, email: "placeholder@example.com")
    end

    before { sign_in(admin) }

    it "can create an admin invite and redeem it end to end" do
      open_invite_modal_for(admin)

      expect(modal).to be_open
      expect(modal).to have_role_toggle
      expect(modal.selected_role).to eq("member")

      modal.select_role("admin")
      screenshot_marker(label: "invite-admins", only: :desktop)

      modal.toggle_advanced_options
      screenshot_marker(label: "invite-admins-advanced", only: :desktop)
      modal.toggle_advanced_options

      modal.form.field("email").fill_in("future-admin@example.com")
      modal.save_button.click

      expect(modal).to have_sent_to_message("future-admin@example.com")
      expect(modal).to have_summary
      screenshot_marker(label: "invite-admin-sent", only: :desktop)

      invite = Invite.last
      expect(invite.admin).to eq(true)
      expect(invite.email).to eq("future-admin@example.com")
      expect(invite.max_redemptions_allowed).to eq(1)
      expect(modal.invite_link_input.value).to eq(invite.link)

      modal.close
      Capybara.reset_sessions!

      invite_form.open(invite.invite_key)
      invite_form.fill_username("futureadmin")
      invite_form.fill_password("supersecurepassword")
      expect(invite_form).to have_valid_fields
      invite_form.click_create_account
      expect(invite_form).to have_successful_message

      invited_user = User.find_by_username("futureadmin")
      expect(invited_user.moderator).to eq(true)
      expect(invited_user.admin).to eq(false)
      expect(AdminConfirmation.exists_for?(invited_user.id)).to eq(true)

      token = Discourse.redis.get("admin-confirmation:#{invited_user.id}")
      AdminConfirmation.find_by_code(token).email_confirmed!
      expect(invited_user.reload.admin).to eq(true)
    end

    it "marks the invite step complete via the create-invite:saved event when inviting an admin" do
      SiteSetting.enable_site_owner_onboarding = true
      banner = PageObjects::Components::AdminOnboardingBanner.new

      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
      screenshot_marker(label: "invite-onboarding-banner", only: :desktop)

      banner.click_step_action("invite_collaborators")
      expect(modal).to be_open
      expect(modal.selected_role).to eq("admin")

      modal.form.field("email").fill_in("collaborator@example.com")
      modal.save_button.click
      expect(modal).to have_summary
      modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)
    end

    it "can create a member link invite with a domain restriction" do
      cdp.allow_clipboard

      open_invite_modal_for(admin)

      expect(modal.selected_role).to eq("member")
      screenshot_marker(label: "invite-members", only: :desktop)

      modal.toggle_advanced_options
      screenshot_marker(label: "invite-members-advanced", only: :desktop)
      modal.toggle_advanced_options

      modal.form.field("domain").fill_in("example.com")
      modal.save_button.click

      expect(modal).to have_summary
      screenshot_marker(label: "invite-created", only: :desktop)

      invite = Invite.last
      expect(invite.admin).to eq(false)
      expect(invite.domain).to eq("example.com")
      cdp.clipboard_has_text?(invite.link)
    end

    it "can create a member email invite" do
      open_invite_modal_for(admin)

      modal.select_delivery("email")
      modal.form.field("email").fill_in("new-member@example.com")
      screenshot_marker(label: "invite-members-email", only: :desktop)
      modal.save_button.click

      expect(modal).to have_email_sent_confirmation("new-member@example.com")
      screenshot_marker(label: "invite-email-sent", only: :desktop)

      invite = Invite.last
      expect(invite.admin).to eq(false)
      expect(invite.email).to eq("new-member@example.com")
    end

    it "locks the role when editing an invite from the summary" do
      open_invite_modal_for(admin)

      modal.select_role("admin")
      modal.form.field("email").fill_in("future-admin@example.com")
      modal.save_button.click
      expect(modal).to have_summary

      modal.edit_button.click

      expect(modal.selected_role).to eq("admin")
      expect(modal.role_option_disabled?("member")).to eq(true)
      expect(modal.save_button).to have_text(I18n.t("js.user.invited.invite_roles.update"))

      modal.cancel_button.click
      expect(modal).to have_summary
    end
  end

  context "when signed in as a regular user who can invite" do
    fab!(:placeholder_invite) do
      Fabricate(:invite, invited_by: user, email: "placeholder@example.com")
    end

    before do
      SiteSetting.invite_allowed_groups = group.id.to_s
      sign_in(user)
    end

    it "does not offer the admins option" do
      open_invite_modal_for(user)

      expect(modal).to be_open
      expect(modal).to have_no_role_toggle
    end
  end

  context "when enable_admin_invites is disabled" do
    fab!(:placeholder_invite) do
      Fabricate(:invite, invited_by: admin, email: "placeholder@example.com")
    end

    before do
      SiteSetting.enable_admin_invites = false
      sign_in(admin)
    end

    it "shows the previous invite modal" do
      open_invite_modal_for(admin)

      expect(page).to have_css(".create-invite-modal")
      expect(page).to have_no_css(".create-invite-with-roles-modal")
    end
  end
end
