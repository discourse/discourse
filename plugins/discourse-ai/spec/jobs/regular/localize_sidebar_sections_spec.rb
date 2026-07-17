# frozen_string_literal: true

describe Jobs::LocalizeSidebarSections do
  subject(:job) { described_class.new }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "pt_BR|zh_CN"

    Jobs.run_immediately!
  end

  it "translates public sidebar sections to configured locales" do
    sidebar_section = Fabricate(:sidebar_section, public: true, locale: "en")

    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, "pt_BR", has_entries(short_text_llm_model: anything))
      .once
    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, "zh_CN", has_entries(short_text_llm_model: anything))
      .once

    job.execute({ limit: 10 })
  end

  it "does not translate when content localization is disabled" do
    SiteSetting.content_localization_enabled = false
    sidebar_section = Fabricate(:sidebar_section, public: true, locale: "en")

    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, any_parameters)
      .never

    job.execute({ limit: 10 })
  end

  it "does not translate private sidebar sections" do
    sidebar_section = Fabricate(:sidebar_section, public: false, locale: "en")

    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, any_parameters)
      .never

    job.execute({ limit: 10 })
  end

  it "skips target locales that match the source locale" do
    sidebar_section = Fabricate(:sidebar_section, public: true, locale: "pt")

    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, "pt_BR", has_entries(short_text_llm_model: anything))
      .never
    DiscourseAi::Translation::SidebarSectionLocalizer
      .expects(:localize)
      .with(sidebar_section, "zh_CN", has_entries(short_text_llm_model: anything))
      .once

    job.execute({ limit: 10 })
  end

  it "clears the anonymous sidebar cache once after translating sidebar sections" do
    Fabricate(:sidebar_section, title: "Public section one", public: true, locale: "en")
    Fabricate(:sidebar_section, title: "Public section two", public: true, locale: "en")

    DiscourseAi::Translation::SidebarSectionLocalizer.stubs(:localize)

    messages = MessageBus.track_publish(Site::SITE_JSON_CHANNEL) { job.execute({ limit: 10 }) }

    expect(messages.size).to eq(1)
  end
end
