# frozen_string_literal: true

describe "Emoji deny list", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:emoji_picker) { PageObjects::Components::EmojiPicker.new }
  fab!(:admin)

  before { sign_in(admin) }

  describe "when editing admin settings" do
    before { SiteSetting.emoji_deny_list = "" }
    let(:site_settings_page) { PageObjects::Pages::AdminSiteSettings.new }

    skip "should allow admin to update emoji deny list" do
      site_settings_page.visit_category("posting")

      site_settings_page.select_from_emoji_list("emoji_deny_list", "fu", false)
      site_settings_page.select_from_emoji_list("emoji_deny_list", "poop")

      expect(site_settings_page.values_in_list("emoji_deny_list")).to eq(%w[fu poop])
    end
  end

  describe "when visiting topics" do
    SiteSetting.emoji_deny_list = "monkey"
    Emoji.clear_cache

    fab!(:topic) { Fabricate(:topic, title: "Time for :monkey: business") }
    fab!(:post) { Fabricate(:post, topic: topic, raw: "We have no time to :monkey: around!") }

    it "should remove denied emojis from page title, heading and body" do
      topic_page.visit_topic(topic)
      expect(page.title).to eq("Time for business - Discourse")
      expect(topic_page).to have_topic_title("Time for business")
      expect(page).not_to have_css(".emoji[title=':monkey:']")
    end
  end

  describe "when using composer" do
    before do
      SiteSetting.enable_emoji = true
      SiteSetting.emoji_deny_list = "fu|poop"
      Emoji.clear_cache && Discourse.request_refresh!
    end

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    xit "should remove denied emojis from emoji picker" do
      topic_page.visit_topic_and_open_composer(topic)
      expect(composer).to be_opened

      composer.click_toolbar_button("insert-composer-emoji")
      expect(composer.emoji_picker).to be_visible

      expect(emoji_picker).to have_no_emoji("fu")
    end

    it "should not show denied emojis and aliases in emoji autocomplete" do
      topic_page.visit_topic_and_open_composer(topic)

      composer.type_content(":poop") # shows no results
      expect(composer).to have_no_emoji_autocomplete

      composer.clear_content

      composer.type_content(":middle") # middle_finger is alias
      expect(composer).to have_no_emoji_suggestion("fu")
    end

    it "should not show denied emoji in preview" do
      topic_page.visit_topic_and_open_composer(topic)

      composer.fill_content(":wave:")
      expect(composer).to have_emoji_preview("wave")

      composer.clear_content

      composer.fill_content(":fu:")
      expect(composer).to have_no_emoji_preview("fu")
    end
  end

  describe "when using private messages" do
    before do
      SiteSetting.emoji_deny_list = "pancakes|monkey"
      Emoji.clear_cache && Discourse.request_refresh!
    end

    fab!(:topic) do
      Fabricate(:private_message_topic, title: "Want to catch up for :pancakes: today?")
    end
    fab!(:post) { Fabricate(:post, topic: topic, raw: "Can we use the :monkey: emoji here?") }

    it "should remove denied emojis from message title and body" do
      topic_page.visit_topic(topic)
      expect(topic_page).to have_topic_title("Want to catch up for today?")
      expect(post).not_to have_css(".emoji[title=':monkey:']")
    end
  end
end
