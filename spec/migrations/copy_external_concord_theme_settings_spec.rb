# frozen_string_literal: true

require Rails.root.join("db/migrate/20261127042422_copy_external_concord_theme_settings.rb")

RSpec.describe CopyExternalConcordThemeSettings do
  let(:url) { "https://github.com/discourse/discourse-concord-theme.git" }
  let!(:external) do
    Fabricate(:theme, name: "Community", remote_theme: Fabricate(:remote_theme, remote_url: url))
  end
  let(:sections) { [{ "name" => "Community", "channels" => [{ "type" => "forum", "id" => 42 }] }] }

  before do
    Theme.concord_theme.delete
    ThemeSettingsMigration.where(theme_id: -3).delete_all
    yaml = File.read(Rails.root.join("themes/concord/settings.yml"))
    external.set_field(
      target: :settings,
      name: :yaml,
      value: yaml.sub("sidebar_sections:", "sidebar_groups:"),
    )
    external.save!
  end

  it "copies only changed settings, including false and the legacy sidebar layout, once" do
    external.update_setting(:show_logo, false)
    external.update_setting(:include_tags, false)
    external.update_setting(:member_list_roles, "2|1")
    external.update_setting(:sidebar_groups, sections)
    SiteSetting.find_or_initialize_by(name: "default_theme_id").update!(
      value: external.id.to_s,
      data_type: SiteSetting.types[:integer],
    )

    described_class.new.up

    expect(SiteSetting.find_by!(name: "default_theme_id").value).to eq(external.id.to_s)
    expect(Theme.concord_theme).to be_nil
    SystemThemesManager.sync_theme!("concord")
    concord = Theme.concord_theme
    expect(concord.theme_settings.pluck(:name)).to contain_exactly(
      "show_logo",
      "member_list_roles",
      "sidebar_sections",
    )
    expect(concord.get_setting(:show_logo)).to be(false)
    expect(concord.get_setting(:member_list_roles)).to eq("2|1")
    expect(concord.get_setting(:sidebar_sections)).to eq(sections)

    concord.theme_settings.find_by!(name: "show_logo").destroy!
    concord.update_setting(:member_list_roles, "1")
    SystemThemesManager.sync_theme!("concord")
    expect(concord.reload.get_setting(:show_logo)).to be(true)
    expect(concord.get_setting(:member_list_roles)).to eq("1")
  end

  it "leaves an incompatible override on the external install and copies the other settings" do
    external.settings_field.update!(value: external.settings_field.value.sub("- voice", "- legacy"))
    layout = [{ "name" => "Community", "channels" => [{ "type" => "legacy", "id" => 42 }] }]
    external.update_setting(:sidebar_groups, layout)
    external.update_setting(:include_tags, true)

    described_class.new.up
    SystemThemesManager.sync_theme!("concord")

    expect(Theme.concord_theme.get_setting(:sidebar_sections)).to eq([])
    expect(Theme.concord_theme.get_setting(:include_tags)).to be(true)
    expect(external.reload.get_setting(:sidebar_groups)).to eq(layout)
  end

  it "uses the default external install when several official copies exist" do
    Fabricate(:theme, remote_theme: Fabricate(:remote_theme, remote_url: url))
    external.remote_theme.update!(
      remote_url: "ssh://git@github.com/discourse/discourse-concord-theme.git",
    )
    external.update_setting(:include_tags, true)
    SiteSetting.find_or_initialize_by(name: "default_theme_id").update!(
      value: external.id.to_s,
      data_type: SiteSetting.types[:integer],
    )

    described_class.new.up
    SystemThemesManager.sync_theme!("concord")

    expect(Theme.concord_theme.get_setting(:include_tags)).to be(true)
  end

  it "preserves an override already saved on the system theme" do
    SystemThemesManager.sync_theme!("concord")
    Theme.concord_theme.update_setting(:member_list_roles, "1")
    external.update_setting(:member_list_roles, "2")
    external.update_setting(:show_logo, false)

    described_class.new.up

    expect(Theme.concord_theme.get_setting(:member_list_roles)).to eq("1")
    expect(Theme.concord_theme.get_setting(:show_logo)).to be(false)
  end

  it "skips ambiguous external installs" do
    Fabricate(:theme, remote_theme: Fabricate(:remote_theme, remote_url: url))
    external.update_setting(:include_tags, true)

    described_class.new.up
    SystemThemesManager.sync_theme!("concord")

    expect(Theme.concord_theme.theme_settings).to be_empty
  end

  it "ignores a same-name theme from another repository" do
    external.update!(name: "Concord")
    external.remote_theme.update!(remote_url: "https://github.com/other/discourse-concord-theme")
    external.update_setting(:include_tags, true)

    described_class.new.up
    SystemThemesManager.sync_theme!("concord")

    expect(Theme.concord_theme.theme_settings).to be_empty
  end
end
