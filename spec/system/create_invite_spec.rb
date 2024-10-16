# frozen_string_literal: true

describe "Creating Invites", type: :system do
  fab!(:group)
  fab!(:user) { Fabricate(:user, groups: [group]) }
  fab!(:admin) { Fabricate(:admin, groups: [group]) }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    SiteSetting.invite_allowed_groups = "#{group.id}"
    SiteSetting.invite_link_max_redemptions_limit_users = 7
    SiteSetting.invite_link_max_redemptions_limit = 63
    SiteSetting.invite_expiry_days = 3
    sign_in(user)
  end

  before do
    visit("/my/invited")
    find(".user-invite-buttons .btn", match: :first).click
  end

  it "is possible to create an invite link without toggling the advanced options" do
    cdp.allow_clipboard

    create_invite_modal.save_button.click
    create_invite_modal.copy_button.click

    cdp.clipboard_has_text?(create_invite_modal.invite_link_input.value)
    expect(create_invite_modal.link_limits_info_paragraph).to have_text(
      "Link is valid for up to 7 users and expires in 3 days.",
    )
  end

  context "with the advanced options" do
    before { create_invite_modal.edit_options_link.click }

    it "replaces the expiresAfterDays field with expiresAt with date and time controls after creating the invite" do
      create_invite_modal.form.field("expiresAfterDays").select(1)
      create_invite_modal.save_button.click
      now = Time.zone.now

      expect(create_invite_modal.form).to have_no_field_with_name("expiresAfterDays")
      expect(create_invite_modal.form).to have_field_with_name("expiresAt")

      expires_at_field = create_invite_modal.form.field("expiresAt").component
      date = expires_at_field.find(".date-picker").value
      time = expires_at_field.find(".time-input").value

      expire_date = Time.parse("#{date} #{time}").utc
      expect(expire_date).to be_within_one_minute_of(now + 1.day)
    end

    context "when an email is given to the restrictTo field" do
      it "shows the customMessage field and hides the maxRedemptions field" do
        expect(create_invite_modal.form).to have_no_field_with_name("customMessage")
        expect(create_invite_modal.form).to have_field_with_name("maxRedemptions")

        create_invite_modal.form.field("restrictTo").fill_in("discourse@cdck.org")

        expect(create_invite_modal.form).to have_field_with_name("customMessage")
        expect(create_invite_modal.form).to have_no_field_with_name("maxRedemptions")
      end
    end
  end
end
