# frozen_string_literal: true

describe DiscourseAi::Translation::SidebarSectionLocaleDetector do
  before { enable_current_plugin }

  fab!(:sidebar_section) { Fabricate(:sidebar_section, title: "Participate", locale: nil) }
  fab!(:sidebar_url) { Fabricate(:sidebar_url, name: "Welcome", value: "/welcome", locale: nil) }

  before do
    sidebar_section.update_column(:locale, nil)
    sidebar_url.update_column(:locale, nil)
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
  end

  def language_detector_stub(text:, locale:)
    detector = instance_double(DiscourseAi::Translation::LanguageDetector)
    allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(text).and_return(
      detector,
    )
    allow(detector).to receive(:detect).and_return(locale)
  end

  it "updates the section and link locale with the detected locale" do
    language_detector_stub(text: "Participate\n\nWelcome", locale: "ja")

    expect { described_class.detect_locale(sidebar_section) }.to change {
      sidebar_section.reload.locale
    }.from(nil).to("ja")

    expect(sidebar_url.reload.locale).to eq("ja")
  end
end
