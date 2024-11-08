# frozen_string_literal: true

describe "Creating Invites", type: :system do
  fab!(:group)
  fab!(:user) { Fabricate(:user, groups: [group]) }
  fab!(:topic) { Fabricate(:post).topic }
  let(:user_invited_pending_page) { PageObjects::Pages::UserInvitedPending.new }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:cdp) { PageObjects::CDP.new }

  def open_invite_modal
    find(".user-invite-buttons .btn", match: :first).click
  end

  def display_advanced_options
    create_invite_modal.edit_options_link.click
  end

  before do
    SiteSetting.invite_allowed_groups = "#{group.id}"
    SiteSetting.invite_link_max_redemptions_limit_users = 7
    SiteSetting.invite_link_max_redemptions_limit = 63
    SiteSetting.invite_expiry_days = 3
    sign_in(user)
  end

  before do
    user_invited_pending_page.visit(user)
    open_invite_modal
  end

  it "is possible to create an invite link without toggling the advanced options" do
    cdp.allow_clipboard

    create_invite_modal.save_button.click
    create_invite_modal.copy_button.click

    invite_link = create_invite_modal.invite_link_input.value
    invite_key = invite_link.split("/").last

    cdp.clipboard_has_text?(invite_link)

    expect(create_invite_modal.link_limits_info_paragraph).to have_text(
      "Link is valid for up to 7 users and expires in 3 days.",
    )

    create_invite_modal.close

    expect(user_invited_pending_page.invites_list.size).to eq(1)

    expect(user_invited_pending_page.latest_invite).to be_link_type(
      key: invite_key,
      redemption_count: 0,
      max_redemption_count: 7,
    )
    expect(user_invited_pending_page.latest_invite.expiry_date).to be_within(2.minutes).of(
      Time.zone.now + 3.days,
    )
  end

  it "has the correct modal title when creating a new invite" do
    expect(create_invite_modal.header).to have_text(I18n.t("js.user.invited.invite.new_title"))
  end

  it "hides the modal footer after creating an invite via simple mode" do
    expect(create_invite_modal).to have_footer
    create_invite_modal.save_button.click
    expect(create_invite_modal).to have_no_footer
  end

  context "when editing an invite" do
    before do
      create_invite_modal.save_button.click
      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)

      user_invited_pending_page.latest_invite.edit_button.click
    end

    it "has the correct modal title" do
      expect(create_invite_modal.header).to have_text(I18n.t("js.user.invited.invite.edit_title"))
    end

    it "displays the invite link and a copy button" do
      expect(create_invite_modal).to have_copy_button
      expect(create_invite_modal).to have_invite_link_input
    end
  end

  context "with the advanced options" do
    before { display_advanced_options }

    it "is possible to populate all the fields" do
      user.update!(admin: true)
      page.refresh
      open_invite_modal
      display_advanced_options

      create_invite_modal.form.field("restrictTo").fill_in("discourse.org")
      create_invite_modal.form.field("maxRedemptions").fill_in("53")
      create_invite_modal.form.field("expiresAfterDays").select(90)

      create_invite_modal.choose_topic(topic)
      create_invite_modal.choose_groups([group])

      create_invite_modal.save_button.click

      expect(create_invite_modal).to have_copy_button

      invite_link = create_invite_modal.invite_link_input.value
      invite_key = invite_link.split("/").last

      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)

      expect(user_invited_pending_page.latest_invite).to be_link_type(
        key: invite_key,
        redemption_count: 0,
        max_redemption_count: 53,
      )
      expect(user_invited_pending_page.latest_invite).to have_group(group)
      expect(user_invited_pending_page.latest_invite).to have_topic(topic)
      expect(user_invited_pending_page.latest_invite.expiry_date).to be_within(2.minutes).of(
        Time.zone.now + 90.days,
      )
    end

    it "is possible to create an email invite and send email to the invited address" do
      Jobs.run_immediately!
      another_group = Fabricate(:group)
      user.update!(admin: true)
      page.refresh
      open_invite_modal
      display_advanced_options

      create_invite_modal.form.field("restrictTo").fill_in("someone@discourse.org")
      create_invite_modal.form.field("expiresAfterDays").select(1)

      create_invite_modal.choose_topic(topic)
      create_invite_modal.choose_groups([group, another_group])

      create_invite_modal
        .form
        .field("customMessage")
        .fill_in("Hello someone, this is a test invite")

      create_invite_modal.save_and_email_button.click

      expect(create_invite_modal).to have_copy_button
      expect(create_invite_modal).to have_alert_message(
        I18n.t("js.user.invited.invite.invite_saved_with_sending_email"),
      )

      invite_link = create_invite_modal.invite_link_input.value

      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)

      expect(user_invited_pending_page.latest_invite).to be_email_type("someone@discourse.org")
      expect(user_invited_pending_page.latest_invite).to have_group(group)
      expect(user_invited_pending_page.latest_invite).to have_group(another_group)
      expect(user_invited_pending_page.latest_invite).to have_topic(topic)
      expect(user_invited_pending_page.latest_invite.expiry_date).to be_within(2.minutes).of(
        Time.zone.now + 1.day,
      )
      sent_email = ActionMailer::Base.deliveries.first
      expect(sent_email.to).to contain_exactly("someone@discourse.org")
      expect(sent_email.parts[0].body.raw_source).to include(invite_link)
    end

    it "is possible to create an email invite without sending an email to the invited address" do
      Jobs.run_immediately!
      create_invite_modal.form.field("restrictTo").fill_in("invitedperson@email.org")
      create_invite_modal.save_button.click

      expect(create_invite_modal).to have_copy_button
      expect(create_invite_modal).to have_alert_message(
        I18n.t("js.user.invited.invite.invite_saved_without_sending_email"),
      )

      invite_link = create_invite_modal.invite_link_input.value

      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)
      expect(user_invited_pending_page.latest_invite).to be_email_type("invitedperson@email.org")
      expect(ActionMailer::Base.deliveries).to eq([])
    end

    it "shows the inviteToGroups field for a normal user if they're owner on at least 1 group" do
      expect(create_invite_modal.form).to have_no_field_with_name("inviteToGroups")

      group.add_owner(user)
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form).to have_field_with_name("inviteToGroups")
    end

    it "shows the inviteToGroups field for admins" do
      user.update!(admin: true)
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form).to have_field_with_name("inviteToGroups")
    end

    it "replaces the expiresAfterDays field with expiresAt with date and time controls after creating the invite" do
      create_invite_modal.form.field("expiresAfterDays").select(1)
      create_invite_modal.save_button.click
      now = Time.zone.now

      expect(create_invite_modal.form).to have_no_field_with_name("expiresAfterDays")
      expect(create_invite_modal.form).to have_field_with_name("expiresAt")

      expires_at_field = create_invite_modal.form.field("expiresAt").component
      date = expires_at_field.find(".date-picker").value
      time = expires_at_field.find(".time-input").value

      expire_date = Time.parse("#{date} #{time}:#{now.strftime("%S")}").utc
      expect(expire_date).to be_within_one_minute_of(now + 1.day)
    end
  end
end
