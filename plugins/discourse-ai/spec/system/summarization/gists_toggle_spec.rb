# frozen_string_literal: true

describe "Gists Toggle Functionality", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:topic_with_gist) { Fabricate(:topic) }
  fab!(:topic_ai_gist) { Fabricate(:topic_ai_gist, target: topic_with_gist) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summary_gists_enabled = true

    group.add(admin)
    assign_persona_to(:ai_summary_gists_persona, [group.id])
    sign_in(admin)
  end

  context "when viewing public topic lists" do
    it "shows toggle when topics have gists" do
      visit("/latest")

      expect(find(".topic-list-layout-trigger")).to be_present
    end

    it "shows gists for public topics" do
      visit("/latest")

      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.expanded"),
      ).click

      expect(page).to have_css("body.topic-list-layout-table-ai")
    end
  end

  context "when viewing PM topic lists" do
    fab!(:pm_topic) { Fabricate(:private_message_topic, user: admin, recipient: Fabricate(:user)) }
    fab!(:pm_gist) { Fabricate(:topic_ai_gist, target: pm_topic) }

    it "shows toggle when PMs have gists" do
      visit("/u/#{admin.username}/messages/new")

      expect(find(".topic-list-layout-trigger")).to be_present
    end

    it "enables gists for PM topics" do
      visit("/u/#{admin.username}/messages/new")

      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.expanded"),
      ).click

      expect(page).to have_css("body.topic-list-layout-table-ai")
    end

    it "PM and public topic toggles are independent from each other" do
      visit("/latest")
      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.compact"),
      ).click

      visit("/u/#{admin.username}/messages/new")
      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.expanded"),
      ).click

      visit("/latest")
      expect(page).to have_css("body.topic-list-layout-table")
      expect(page).not_to have_css("body.topic-list-layout-table-ai")

      visit("/u/#{admin.username}/messages/new")
      expect(page).to have_css("body.topic-list-layout-table-ai")
      expect(page).not_to have_css("body.topic-list-layout-table")
    end
  end

  context "when no gists are available" do
    before { topic_ai_gist.destroy! }

    it "does not show toggle for topics without gists" do
      visit("/latest")

      expect(page).not_to have_css(".topic-list-layout-trigger")
    end
  end

  context "when viewing gists on desktop" do
    it "renders gist component in desktop outlet" do
      visit("/latest")

      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.expanded"),
      ).click

      expect(page).to have_css(".link-bottom-line .excerpt__contents")
    end
  end
end

describe "Gists Toggle Functionality - Mobile", type: :system, mobile: true do
  fab!(:admin)
  fab!(:group)
  fab!(:topic_with_gist, :topic)
  fab!(:topic_ai_gist) { Fabricate(:topic_ai_gist, target: topic_with_gist) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summary_gists_enabled = true

    group.add(admin)
    assign_persona_to(:ai_summary_gists_persona, [group.id])
    sign_in(admin)
  end

  context "when viewing gists on mobile" do
    it "renders gist component in mobile outlet" do
      visit("/latest")

      find(".topic-list-layout-trigger").click
      find(
        ".dropdown-menu__item .d-button-label",
        text: I18n.t("js.discourse_ai.summarization.topic_list_layout.button.expanded"),
      ).click

      expect(page).to have_css(".topic-item-stats__category-tags .excerpt__contents")
    end
  end
end
