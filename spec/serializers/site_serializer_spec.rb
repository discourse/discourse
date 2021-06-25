# frozen_string_literal: true

require 'rails_helper'

describe SiteSerializer do
  let(:guardian) { Guardian.new }
  let(:category) { Fabricate(:category) }

  after do
    Site.clear_cache
  end

  it "includes category custom fields only if its preloaded" do
    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:custom_fields]).to eq(nil)

    Site.preloaded_category_custom_fields << "enable_marketplace"
    Site.clear_cache

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:custom_fields]["enable_marketplace"]).to eq("t")
  ensure
    Site.preloaded_category_custom_fields.clear
  end

  it "includes category tags" do
    tag = Fabricate(:tag)
    tag_group = Fabricate(:tag_group)
    tag_group_2 = Fabricate(:tag_group)

    category.tags << tag
    category.tag_groups << tag_group
    category.update!(required_tag_group: tag_group_2)

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:allowed_tags]).to contain_exactly(tag.name)
    expect(c1[:allowed_tag_groups]).to contain_exactly(tag_group.name)
    expect(c1[:required_tag_group_name]).to eq(tag_group_2.name)
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
