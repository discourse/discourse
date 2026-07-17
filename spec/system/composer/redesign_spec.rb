# frozen_string_literal: true

describe "Composer redesign" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(user) }

  context "when enable_composer_redesign is enabled" do
    before { SiteSetting.enable_composer_redesign = true }

    it "lets the user create a topic with the redesigned composer" do
      visit("/new-topic")

      expect(composer).to be_opened
      expect(composer).to have_footer_toolbar
      expect(composer).to have_title_below_category_row

      composer.fill_title("Topic from the redesigned composer")
      composer.fill_content("The content of the topic")
      composer.submit

      expect(topic_page).to have_topic_title("Topic from the redesigned composer")
      expect(topic_page).to have_post_content(post_number: 1, content: "The content of the topic")
    end

    it "lets the user reply to a topic with the redesigned composer" do
      topic_page.visit_topic(topic)
      topic_page.click_reply_button

      expect(composer).to be_opened
      expect(composer).to have_footer_toolbar

      composer.fill_content("A reply from the redesigned composer")
      composer.submit

      expect(topic_page).to have_post_content(
        post_number: 2,
        content: "A reply from the redesigned composer",
      )
    end

    it "shows the recipient selector in the top row when the user composes a personal message" do
      visit("/new-message")

      expect(composer).to be_opened
      expect(composer).to have_pm_recipients_in_category_row
      expect(composer).to have_title_below_category_row
    end

    it "keeps the toolbar visible in the footer on mobile", mobile: true do
      visit("/new-topic")

      expect(composer).to be_opened
      expect(composer).to have_footer_toolbar
      expect(composer).to have_no_toggle_toolbar_button
    end
  end

  context "when enable_composer_redesign is disabled" do
    before { SiteSetting.enable_composer_redesign = false }

    it "shows the user the legacy composer layout" do
      visit("/new-topic")

      expect(composer).to be_opened
      expect(composer).to have_inline_toolbar
      expect(composer).to have_no_footer_toolbar
      expect(composer).to have_title_in_category_row
    end

    it "lets the user hide and show the toolbar on mobile", mobile: true do
      visit("/new-topic")

      expect(composer).to be_opened
      expect(composer).to have_visible_toolbar

      composer.toggle_toolbar
      expect(composer).to have_no_visible_toolbar

      composer.toggle_toolbar
      expect(composer).to have_visible_toolbar
    end
  end
end
