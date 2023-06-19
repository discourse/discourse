# frozen_string_literal: true

describe "Community sidebar section", type: :system do
  fab!(:user) { Fabricate(:user, locale: "pl_PL") }
  fab!(:translation_override) do
    TranslationOverride.create!(
      locale: "pl_PL",
      translation_key: "js.sidebar.sections.community.links.topics.content",
      value: "Tematy",
    )
    TranslationOverride.create!(
      locale: "pl_PL",
      translation_key: "js.sidebar.sections.community.links.topics.title",
      value: "Wszystkie tematy",
    )
  end

  before { SiteSetting.allow_user_locale = true }

  it "has correct translations" do
    sign_in user
    visit("/latest")
    links = page.all("#sidebar-section-content-community .sidebar-section-link-wrapper a")
    expect(links.map(&:text)).to eq(%w[Tematy Wysłane])
    expect(links.map { |link| link[:title] }).to eq(
      ["Wszystkie tematy", "Moja ostatnia aktywność w temacie"],
    )
  end
end
