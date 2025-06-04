# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20250526063633_copy_add_groups_to_about_component_settings.rb",
        )

RSpec.describe CopyAddGroupsToAboutComponentSettings do
  let(:migrate) { described_class.new.up }
  fab!(:component) do
    Fabricate(:theme, name: "Add Groups to About", enabled: true, component: true)
  end
  fab!(:component_2) do
    Fabricate(:theme, name: "Add Groups to About", enabled: true, component: true)
  end
  fab!(:theme_setting_1) do
    ThemeSetting.create!(
      theme: component,
      name: "about_groups",
      value: "0|1",
      updated_at: 1.day.ago,
      data_type: 4,
    )
  end
  fab!(:theme_setting_2) do
    ThemeSetting.create!(
      theme: component,
      name: "order_additional_groups",
      value: "whatever old value",
      updated_at: 2.day.ago,
      data_type: 5,
    )
  end
  fab!(:theme_setting_3) do
    ThemeSetting.create!(
      theme: component,
      name: "show_group_description",
      value: "true",
      updated_at: 1.day.ago,
      data_type: 3,
    )
  end
  fab!(:theme_setting_4) do
    ThemeSetting.create!(
      theme: component,
      name: "show_initial_members",
      value: "whatever old value",
      updated_at: 2.day.ago,
      data_type: 0,
    )
  end
  fab!(:theme_setting_5) do
    ThemeSetting.create!(
      theme: component_2,
      name: "about_groups",
      value: "whatever old value",
      updated_at: 2.day.ago,
      data_type: 4,
    )
  end
  fab!(:theme_setting_6) do
    ThemeSetting.create!(
      theme: component_2,
      name: "order_additional_groups",
      value: "order of creation",
      updated_at: 1.day.ago,
      data_type: 5,
    )
  end
  fab!(:theme_setting_7) do
    ThemeSetting.create!(
      theme: component_2,
      name: "show_group_description",
      value: "whatever old value",
      updated_at: 2.day.ago,
      data_type: 3,
    )
  end
  fab!(:theme_setting_8) do
    ThemeSetting.create!(
      theme: component_2,
      name: "show_initial_members",
      value: "12",
      updated_at: 1.day.ago,
      data_type: 0,
    )
  end
  before do
    @original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
  end

  after { SiteSetting.provider = @original_provider }

  it "migrates the most updated settings" do
    silence_stdout { migrate }
    SiteSetting.refresh!
    expect(SiteSetting.about_page_extra_groups).to eq("0|1")
    expect(SiteSetting.about_page_extra_groups_order).to eq("order of creation")
    expect(SiteSetting.about_page_extra_groups_show_description).to be true
    expect(SiteSetting.about_page_extra_groups_initial_members).to eq(12)
  end
end
