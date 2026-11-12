# frozen_string_literal: true

describe DiscourseAi::Translation::SidebarSectionLocalizer do
  subject(:localizer) { described_class }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
  end

  fab!(:sidebar_section) { Fabricate(:sidebar_section, title: "Participate") }
  fab!(:sidebar_url) { Fabricate(:sidebar_url, name: "Welcome", value: "/welcome") }

  before { Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url) }

  def short_text_translator_stub(text:, target_locale:, translated:)
    translator = instance_double(DiscourseAi::Translation::ShortTextTranslator)
    allow(DiscourseAi::Translation::ShortTextTranslator).to receive(:new).with(
      text:,
      target_locale:,
      llm_model: be_nil,
    ).and_return(translator)
    allow(translator).to receive(:translate).and_return(translated)
  end

  it "translates the sidebar section title and link names" do
    short_text_translator_stub(text: "Participate", target_locale: "ja", translated: "参加")
    short_text_translator_stub(text: "Welcome", target_locale: "ja", translated: "ようこそ")

    localization = localizer.localize(sidebar_section, "ja")

    expect(localization).to have_attributes(locale: "ja", title: "参加")
    expect(sidebar_url.localizations.last).to have_attributes(locale: "ja", name: "ようこそ")
  end

  it "updates existing localizations" do
    existing = Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "古い")
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "古い")
    short_text_translator_stub(text: "Participate", target_locale: "ja", translated: "参加")
    short_text_translator_stub(text: "Welcome", target_locale: "ja", translated: "ようこそ")

    expect { localizer.localize(sidebar_section, "ja") }.not_to change {
      SidebarSectionLocalization.count
    }

    expect(existing.reload.title).to eq("参加")
    expect(sidebar_url.localizations.last.reload.name).to eq("ようこそ")
  end

  it "does not translate built-in sidebar sections" do
    community_section =
      SidebarSection.find_by(section_type: SidebarSection.section_types[:community])

    expect { localizer.localize(community_section, "ja") }.not_to change {
      SidebarSectionLocalization.count
    }
  end
end
