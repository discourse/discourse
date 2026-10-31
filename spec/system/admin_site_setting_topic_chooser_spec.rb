# frozen_string_literal: true

describe "Admin Site Setting Topic Selector Component" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }

  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, title: "Moderator guide", fancy_title: "Moderator guide") }
  fab!(:post) { Fabricate(:post, topic: topic) }

  before { sign_in(admin) }

  it "can configure the setting with a topic" do
    settings_page.visit
    settings_page.type_in_search("moderator guide topic")

    expect(settings_page).to have_n_results(1)

    settings_page.find(".topic-chooser > summary").click

    expect(settings_page).to have_css("input.filter-input")

    settings_page.find("input.filter-input").fill_in(with: topic.id)
    settings_page.find(".topic-row").click

    expect(settings_page).to have_css(".selected-name", text: "Moderator guide")

    banner.click_save

    expect(settings_page).to have_overridden_topic_setting("moderator_guide_topic", value: topic.id)
  end

  it "can load a topics title when loading the component" do
    SiteSetting.moderator_guide_topic = topic.id

    settings_page.visit
    settings_page.type_in_search("moderator guide topic")

    expect(settings_page).to have_n_results(1)

    expect(settings_page).to have_css(".selected-name", text: "Moderator guide")
  end

  context "with the new select controls" do
    let(:topic_picker) { PageObjects::Components::UiKit::DSelect.at(".d-select.topic-chooser") }

    before { SiteSetting.enable_new_select_controls = true }

    it "can configure the setting with a topic found by its id" do
      settings_page.visit
      settings_page.type_in_search("moderator guide topic")

      expect(settings_page).to have_n_results(1)

      topic_picker.search(topic.id)
      topic_picker.select_value(topic.id)

      expect(topic_picker).to have_selected_name("Moderator guide")

      banner.click_save

      expect(settings_page).to have_overridden_topic_setting(
        "moderator_guide_topic",
        value: topic.id,
      )
    end

    it "names the held topic when the page loads" do
      SiteSetting.moderator_guide_topic = topic.id

      settings_page.visit
      settings_page.type_in_search("moderator guide topic")

      expect(topic_picker).to have_selected_name("Moderator guide")
    end
  end
end
