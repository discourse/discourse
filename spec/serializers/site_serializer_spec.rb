# frozen_string_literal: true

require 'rails_helper'

describe SiteSerializer do
  let(:guardian) { Guardian.new }
  let(:category) { Fabricate(:category) }

  it "includes category custom fields only if its preloaded" do
    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).not_to include("enable_marketplace")

    Site.preloaded_category_custom_fields << "enable_marketplace"

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).to include("enable_marketplace")
  end

  it "returns correct notification level for categories" do
    SiteSetting.mute_all_categories_by_default = true
    SiteSetting.default_categories_regular = category.id.to_s

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    categories = serialized[:categories]
    expect(categories[0][:notification_level]).to eq(0)
    expect(categories[-1][:notification_level]).to eq(1)
  end

  it "includes user-selectable color schemes" do
    # it includes seeded color schemes
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:user_color_schemes].count).to eq(3)

    scheme_names = serialized[:user_color_schemes].map { |x| x[:name] }
    expect(scheme_names).to include(I18n.t("color_schemes.dark"))
    expect(scheme_names).to include(I18n.t("color_schemes.wcag"))
    expect(scheme_names).to include(I18n.t("color_schemes.wcag_dark"))

    dark_scheme = ColorScheme.create_from_base(name: "AnotherDarkScheme", base_scheme_id: "Dark")
    dark_scheme.user_selectable = true
    dark_scheme.save!

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:user_color_schemes].count).to eq(4)
    expect(serialized[:user_color_schemes][0][:is_dark]).to eq(true)
  end

  it "includes default dark mode scheme" do
    scheme = ColorScheme.last
    SiteSetting.default_dark_mode_color_scheme_id = scheme.id
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    default_dark_scheme =
    expect(serialized[:default_dark_color_scheme]["name"]).to eq(scheme.name)

    SiteSetting.default_dark_mode_color_scheme_id = -1
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:default_dark_color_scheme]).to eq(nil)
  end

  it 'does not include shared_drafts_category_id if the category is Uncategorized' do
    admin = Fabricate(:admin)
    admin_guardian = Guardian.new(admin)

    SiteSetting.shared_drafts_category = SiteSetting.uncategorized_category_id

    serialized = described_class.new(Site.new(admin_guardian), scope: admin_guardian, root: false).as_json
    expect(serialized[:shared_drafts_category_id]).to eq(nil)
  end
end
