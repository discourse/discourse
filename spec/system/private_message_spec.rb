# frozen_string_literal: true

describe "Private Message", type: :system do
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

    it "should be available in new topic" do
      visit "/new-topic"
      expect(composer).to be_opened

      composer.open_composer_actions
      composer.select_action("New message")

      expect(composer.button_label).to have_text(I18n.t("js.composer.create_pm"))
    end

    it "should not be available in private conversation reply" do
      visit(pm_post.full_url)

      pm_post_obj.reply
      expect(composer).to be_opened

      composer.open_composer_actions
      expect(composer).to have_no_action("New message")
    end
  end
end
