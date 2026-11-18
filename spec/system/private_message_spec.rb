# frozen_string_literal: true

describe "Private Message" do
  let(:sender) { Fabricate(:user, refresh_auto_groups: true) }
  let(:recipient) { Fabricate(:user) }
  let(:pm_post) { Fabricate(:private_message_post, user: sender, recipient: recipient) }
  let(:pm_post_obj) { PageObjects::Components::Post.new(pm_post.post_number) }
  let(:composer) { PageObjects::Components::Composer.new }

  context "when being removed from private conversation" do
    before { sign_in(recipient) }

    it "redirects away from the private message" do
      visit(pm_post.full_url)

      expect(page).to have_css("h1", text: pm_post.topic.title)

      pm_post.topic.remove_allowed_user(sender, recipient)

      expect(page).to have_current_path("/u/#{recipient.username}/messages")
      expect(page).to have_no_css("h1", text: pm_post.topic.title)
    end
  end

  context "for 'new personal message' action option in composer" do
    before { sign_in(sender) }

    it "offers the personal message action in a new topic" do
      visit "/new-topic"
      expect(composer).to be_opened

      composer.open_composer_actions
      composer.select_action_by_id("create_private_message")

      expect(composer.button_label).to have_text(I18n.t("js.composer.create_pm"))
    end

    it "omits the personal message action when replying to a private conversation" do
      visit(pm_post.full_url)

      pm_post_obj.reply
      expect(composer).to be_opened

      composer.open_composer_actions
      expect(composer).to have_no_action_id("create_private_message")
    end

    it "can switch between topic and personal message modes" do
      visit "/new-topic"
      expect(composer).to be_opened

      # Switch to personal message
      composer.open_composer_actions
      composer.select_action_by_id("create_private_message")
      expect(composer.button_label).to have_text(I18n.t("js.composer.create_pm"))

      # Switch back to topic
      composer.open_composer_actions
      composer.select_action_by_id("create_topic")
      expect(composer.button_label).to have_text(I18n.t("js.composer.create_topic"))
    end
  end

  context "when staff can add badge holders as recipients" do
    fab!(:moderator)
    fab!(:badge)
    fab!(:badge_holder, :user)
    fab!(:other_recipient, :user)

    before do
      SiteSetting.enable_badge_holder_pm_recipients = true
      Fabricate(:user_badge, badge:, user: badge_holder)
      sign_in(moderator)
    end

    it "adds badge holders to the draft alongside manually selected recipients" do
      visit "/new-topic"
      composer.open_composer_actions
      composer.select_action_by_id("create_private_message")
      composer.select_pm_user(other_recipient.username)

      find(".composer-add-badge-holders").click
      badge_picker = PageObjects::Components::SelectKit.new(".pm-badge-holder-picker .combo-box")
      badge_picker.select_row_by_value(badge.id)
      expect do
        within(".pm-badge-holder-picker") { click_button I18n.t("js.composer.add_badge_holders") }
        expect(page).to have_no_css(".pm-badge-holder-picker")
      end.not_to change { Topic.where(archetype: Archetype.private_message).count }

      recipients = PageObjects::Components::SelectKit.new("#private-message-users")
      expect(recipients).to have_selected_names(other_recipient.username, badge_holder.username)
    end
  end
end
