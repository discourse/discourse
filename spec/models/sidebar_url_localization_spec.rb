# frozen_string_literal: true

describe SidebarUrlLocalization do
  it "enforces one localization per sidebar URL and locale" do
    sidebar_url = Fabricate(:sidebar_url)
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja")

    localization = Fabricate.build(:sidebar_url_localization, sidebar_url:, locale: "ja")

    expect(localization).not_to be_valid
    expect(localization.errors.details[:sidebar_url_id]).to contain_exactly(include(error: :taken))
  end
end
