# frozen_string_literal: true

describe SidebarSectionLocalization do
  it "enforces one localization per sidebar section and locale" do
    sidebar_section = Fabricate(:sidebar_section)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja")

    localization = Fabricate.build(:sidebar_section_localization, sidebar_section:, locale: "ja")

    expect(localization).not_to be_valid
    expect(localization.errors.details[:sidebar_section_id]).to contain_exactly(
      include(error: :taken),
    )
  end
end
