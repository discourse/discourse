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

    invite = user_invited_pending_page.invites_list[0]
    expect(invite).to be_link_type(key: invite_key, redemption_count: 0, max_redemption_count: 7)
    expect(invite.expiry_date).to be_within(2.minutes).of(Time.zone.now + 3.days)
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

      invite = user_invited_pending_page.invites_list[0]
      invite.edit_button.click
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

      topic_picker = PageObjects::Components::SelectKit.new(".topic-chooser")
      topic_picker.expand
      topic_picker.search(topic.id)
      topic_picker.select_row_by_index(0)

      group_picker = PageObjects::Components::SelectKit.new(".group-chooser")
      group_picker.expand
      group_picker.select_row_by_value(group.id)
      group_picker.collapse

      create_invite_modal.save_button.click

      expect(create_invite_modal).to have_copy_button

      invite_link = create_invite_modal.invite_link_input.value
      invite_key = invite_link.split("/").last

      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)

      invite = user_invited_pending_page.invites_list[0]
      expect(invite).to be_link_type(key: invite_key, redemption_count: 0, max_redemption_count: 53)
      expect(invite).to have_group(group)
      expect(invite).to have_topic(topic)
      expect(invite.expiry_date).to be_within(2.minutes).of(Time.zone.now + 90.days)
    end

    it "is possible to create an email invite" do
      another_group = Fabricate(:group)
      user.update!(admin: true)
      page.refresh
      open_invite_modal
      display_advanced_options

      create_invite_modal.form.field("restrictTo").fill_in("someone@discourse.org")
      create_invite_modal.form.field("expiresAfterDays").select(1)

      topic_picker = PageObjects::Components::SelectKit.new(".topic-chooser")
      topic_picker.expand
      topic_picker.search(topic.id)
      topic_picker.select_row_by_index(0)

      group_picker = PageObjects::Components::SelectKit.new(".group-chooser")
      group_picker.expand
      group_picker.select_row_by_value(group.id)
      group_picker.select_row_by_value(another_group.id)
      group_picker.collapse

      create_invite_modal
        .form
        .field("customMessage")
        .fill_in("Hello someone, this is a test invite")

      create_invite_modal.save_button.click

      expect(create_invite_modal).to have_copy_button

      invite_link = create_invite_modal.invite_link_input.value
      invite_key = invite_link.split("/").last

      create_invite_modal.close

      expect(user_invited_pending_page.invites_list.size).to eq(1)

      invite = user_invited_pending_page.invites_list[0]
      expect(invite).to be_email_type("someone@discourse.org")
      expect(invite).to have_group(group)
      expect(invite).to have_group(another_group)
      expect(invite).to have_topic(topic)
      expect(invite.expiry_date).to be_within(2.minutes).of(Time.zone.now + 1.day)
    end

    it "adds the invite_expiry_days site setting to the list of options for the expiresAfterDays field" do
      options =
        create_invite_modal
          .form
          .field("expiresAfterDays")
          .component
          .all(".form-kit__control-option")
          .map(&:text)
      expect(options).to eq(["1 day", "3 days", "7 days", "30 days", "90 days", "Never"])

      SiteSetting.invite_expiry_days = 90

      options =
        create_invite_modal
          .form
          .field("expiresAfterDays")
          .component
          .all(".form-kit__control-option")
          .map(&:text)
      expect(options).to eq(["1 day", "7 days", "30 days", "90 days", "Never"])
    end

    it "uses the invite_link_max_redemptions_limit_users setting as the default value for the maxRedemptions field if the setting is lower than 10" do
      expect(create_invite_modal.form.field("maxRedemptions").value).to eq("7")

      SiteSetting.invite_link_max_redemptions_limit_users = 11
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form.field("maxRedemptions").value).to eq("10")
    end

    it "uses the invite_link_max_redemptions_limit setting as the default value for the maxRedemptions field for staff users if the setting is lower than 100" do
      user.update!(admin: true)
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form.field("maxRedemptions").value).to eq("63")

      SiteSetting.invite_link_max_redemptions_limit = 108
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form.field("maxRedemptions").value).to eq("100")
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

    it "doesn't show the inviteToTopic field to normal users" do
      SiteSetting.must_approve_users = false
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form).to have_no_field_with_name("inviteToTopic")
    end

    it "shows the inviteToTopic field to admins if the must_approve_users setting is false" do
      user.update!(admin: true)
      SiteSetting.must_approve_users = false
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form).to have_field_with_name("inviteToTopic")
    end

    it "doesn't show the inviteToTopic field to admins if the must_approve_users setting is true" do
      user.update!(admin: true)
      SiteSetting.must_approve_users = true
      page.refresh
      open_invite_modal
      display_advanced_options

      expect(create_invite_modal.form).to have_no_field_with_name("inviteToTopic")
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
