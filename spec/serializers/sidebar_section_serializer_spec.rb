# frozen_string_literal: true

describe SidebarSectionSerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:sidebar_section) do
    Fabricate(:sidebar_section, title: "Participate", public: true, locale: "en")
  end
  fab!(:sidebar_url) { Fabricate(:sidebar_url, name: "Welcome", value: "/welcome", locale: "en") }

  before do
    Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
    Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "参加")
    Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "ようこそ")
  end

  def serialized_for(guardian)
    reloaded =
      SidebarSection.includes(:localizations, sidebar_urls: :localizations).find(sidebar_section.id)
    described_class.new(reloaded, scope: guardian, root: false).as_json
  end

  it "returns localized section titles and link names when content localization is enabled" do
    SiteSetting.content_localization_enabled = true

    I18n.with_locale("ja") do
      json = serialized_for(Guardian.new(user))

      expect(json[:title]).to eq("参加")
      expect(json[:links].first[:name]).to eq("ようこそ")
    end
  end

  it "returns original labels when content localization is disabled" do
    SiteSetting.content_localization_enabled = false

    I18n.with_locale("ja") do
      json = serialized_for(Guardian.new(user))

      expect(json[:title]).to eq("Participate")
      expect(json[:links].first[:name]).to eq("Welcome")
    end
  end

  it "only exposes localization rows to admins who can edit the sidebar section" do
    SiteSetting.content_localization_enabled = true

    expect(serialized_for(Guardian.new(user))[:localizations]).to eq(nil)
    expect(serialized_for(Guardian.new(admin))[:localizations].first[:title]).to eq("参加")
    expect(serialized_for(Guardian.new(admin))[:links].first[:localizations].first[:name]).to eq(
      "ようこそ",
    )
  end

  it "returns original labels for private sections with localizations" do
    SiteSetting.content_localization_enabled = true
    private_section = Fabricate(:sidebar_section, title: "Private section", locale: "en", user:)
    private_url = Fabricate(:sidebar_url, name: "Private link", value: "/private", locale: "en")
    Fabricate(:sidebar_section_link, sidebar_section: private_section, linkable: private_url)
    Fabricate(
      :sidebar_section_localization,
      sidebar_section: private_section,
      locale: "ja",
      title: "非公開セクション",
    )
    Fabricate(:sidebar_url_localization, sidebar_url: private_url, locale: "ja", name: "非公開リンク")

    I18n.with_locale("ja") do
      reloaded =
        SidebarSection.includes(:localizations, sidebar_urls: :localizations).find(
          private_section.id,
        )
      json = described_class.new(reloaded, scope: Guardian.new(user), root: false).as_json

      expect(json[:title]).to eq("Private section")
      expect(json[:links].first[:name]).to eq("Private link")
    end
  end
end
