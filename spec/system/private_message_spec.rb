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
      browser_page.goto(pm_post.full_url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator("h1").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(pm_post.topic.title)],
        useInnerText: true,
      )

      pm_post.topic.remove_allowed_user(sender, recipient)

      expect(browser_page).to PlaywrightMatchers.have_url("/u/#{recipient.username}/messages")
      expect(
        browser_root.locator("h1").filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern(pm_post.topic.title)],
        useInnerText: true,
      )
    end
  end

  context "for 'new personal message' action option in composer" do
    before { sign_in(sender) }

    it "offers the personal message action in a new topic" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      composer.open_composer_actions
      composer.select_action_by_id("create_private_message")

      expect(composer.button_label).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.composer.create_pm")),
        useInnerText: true,
      )
    end

    it "omits the personal message action when replying to a private conversation" do
      browser_page.goto(pm_post.full_url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      pm_post_obj.reply
      expect(composer).to be_opened

      composer.open_composer_actions
      expect(composer).to have_no_action_id("create_private_message")
    end

    it "can switch between topic and personal message modes" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      # Switch to personal message
      composer.open_composer_actions
      composer.select_action_by_id("create_private_message")
      expect(composer.button_label).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.composer.create_pm")),
        useInnerText: true,
      )

      # Switch back to topic
      composer.open_composer_actions
      composer.select_action_by_id("create_topic")
      expect(composer.button_label).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.composer.create_topic")),
        useInnerText: true,
      )
    end
  end
end
