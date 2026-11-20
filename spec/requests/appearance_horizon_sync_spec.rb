# frozen_string_literal: true

RSpec.describe "Synced Horizon appearance changes", type: :request do
  fab!(:admin)

  let(:styles) { { variables: { "--d-border-radius" => "12px" } } }
  let(:params) do
    {
      name: "Rounded Horizon",
      base_theme_id: Theme::CORE_THEMES["horizon"],
      light_colors:
        ColorScheme.base_colors.transform_values do |hex|
          hex.size == 3 ? hex.chars.map { |character| character * 2 }.join : hex
        end,
      dark_colors: ColorScheme::BUILT_IN_SCHEMES[:Dark],
      styles:,
    }
  end

  def save_change
    result = AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)
    expect(result).to run_successfully
    result[:appearance_change]
  end

  def scss(theme)
    theme.reload.theme_fields.find_by!(target_id: Theme.targets[:common], name: "scss").value
  end

  before do
    SystemThemesManager.sync_theme!("horizon")
    Theme.horizon_theme.set_default!
  end

  it "saves an isolated copy, previews it, activates it and restores Horizon" do
    original = scss(Theme.horizon_theme)
    change = save_change

    expect(change.theme_id).to be_positive
    expect(change.theme.component?).to eq(false)
    expect(change.base_theme_id).to eq(Theme.horizon_theme.id)
    expect(scss(change.theme)).to eq("#{original}\n#{change.css}")
    expect(change.theme.theme_fields.where(type_id: ThemeField.types[:js])).to exist
    expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)

    sign_in(admin)
    get "/", params: { preview_theme_id: change.theme_id }
    expect(response.status).to eq(200)
    expect(controller.theme_id).to eq(change.theme_id)
    expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)

    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    expect(SiteSetting.default_theme_id).to eq(change.theme_id)

    expect(
      AppearanceChange::Revert.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)
    expect(scss(Theme.horizon_theme)).to eq(original)
  end

  it "imports subsequent bundled updates into copies without accumulating generated styles" do
    change = save_change
    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    palette_ids = change.theme.attributes.values_at("color_scheme_id", "dark_color_scheme_id")

    Dir.mktmpdir("horizon-update") do |directory|
      FileUtils.cp_r(Rails.root.join("themes/horizon/.").to_s, directory)
      File.write(
        File.join(directory, "common/common.scss"),
        ".phase-three-update { border-radius: 3px; }",
      )
      File.write(
        File.join(directory, "desktop/desktop.scss"),
        ".phase-three-desktop { margin: 1px; }",
      )
      importer = ThemeStore::DirectoryImporter.new(directory)
      ThemeStore::DirectoryImporter
        .stubs(:new)
        .with(Rails.root.join("themes/horizon").to_s)
        .returns(importer)

      2.times { SystemThemesManager.sync_theme!("horizon") }

      expect(scss(change.theme)).to eq(".phase-three-update { border-radius: 3px; }\n#{change.css}")
      expect(scss(Theme.horizon_theme)).not_to include(change.css)
      expect(SiteSetting.default_theme_id).to eq(change.theme_id)
      expect(change.theme.name).to eq("Rounded Horizon")
      expect(change.theme.attributes.values_at("color_scheme_id", "dark_color_scheme_id")).to eq(
        palette_ids,
      )
      expect(
        change.theme.theme_fields.find_by!(target_id: Theme.targets[:desktop], name: "scss").value,
      ).to include("phase-three-desktop")
    end
  end

  it "rejects unsupported bases" do
    params[:base_theme_id] = Theme::CORE_THEMES["foundation"]
    expect(AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)).to fail_a_policy(
      :supported_base_theme,
    )
  end

  it "honors restrictions on editing the source theme" do
    Guardian.any_instance.stubs(:can_edit_theme?).with(Theme.horizon_theme).returns(false)
    expect(AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)).to fail_a_policy(
      :supported_base_theme,
    )
  end

  def activate(change)
    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
  end

  it "recognizes copied source files as managed and keeps the design wizard available" do
    change = save_change
    activate(change)
    expect(change.theme_unchanged?).to eq(true)
    expect(AppearanceChange.managed_theme_ids).to include(change.theme_id)
    expect(
      CurrentUserSerializer.new(admin, scope: admin.guardian).include_can_run_design_wizard?,
    ).to eq(true)
  end

  it "carries supported settings and attaches the same component records, not duplicates" do
    source = Theme.horizon_theme
    source.update_setting(:topic_card_high_context, false)
    source.theme_site_settings.find_by!(name: "enable_welcome_banner").update!(value: "f")
    component = Fabricate(:theme, component: true)
    source.child_themes << component
    component_count = Theme.where(component: true).count
    change = save_change

    expect(change.theme.settings[:topic_card_high_context].value).to eq(false)
    expect(change.theme.theme_site_settings.find_by!(name: "enable_welcome_banner").value).to eq(
      "f",
    )
    expect(change.theme.child_theme_ids).to eq([component.id])
    expect(Theme.where(component: true).count).to eq(component_count)
    expect(change.theme_unchanged?).to eq(true)
    expect(
      CurrentUserSerializer.new(admin, scope: admin.guardian).include_can_run_design_wizard?,
    ).to eq(true)
    SystemThemesManager.sync_theme!("horizon")
    expect(change.theme.reload.settings[:topic_card_high_context].value).to eq(false)
    expect(change.theme.child_theme_ids).to eq([component.id])
    change.discard!
    expect(Theme.exists?(component.id)).to eq(true)
    expect(Theme.horizon_theme.child_theme_ids).to eq([component.id])
  end

  it "inherits Horizon for revisions and prunes older untouched copies" do
    first = save_change
    activate(first)
    params[:replaces_theme_id] = first.theme_id
    params.delete(:base_theme_id)
    second = save_change
    expect(second.base_theme_id).to eq(Theme.horizon_theme.id)
    expect(second.theme.name).to eq("Rounded Horizon (draft)")
    expect(second.versions_changed_on_activation).to eq([first.theme])
    activate(second)
    expect(first.theme.reload.name).to eq("Rounded Horizon (previous)")
    params[:replaces_theme_id] = second.theme_id
    third = save_change
    expect(third.versions_changed_on_activation.map(&:id)).to contain_exactly(
      first.theme_id,
      second.theme_id,
    )
    activate(third)
    expect(Theme.exists?(first.theme_id)).to eq(false)
    expect(second.theme.reload.name).to eq("Rounded Horizon (previous)")
    expect(
      AppearanceChange::Revert.call(
        params: {
          appearance_change_id: third.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    expect(SiteSetting.default_theme_id).to eq(second.theme_id)
  end

  it "cleans up abandoned copies after source updates without leaking bundled palettes" do
    count = ColorScheme.unscoped.count
    change = save_change
    expect(ColorScheme.unscoped.count).to eq(count + 2)
    freeze_time 1.day.from_now do
      SystemThemesManager.sync_theme!("horizon")
      change.reload.discard!
    end
    expect(Theme.exists?(change.theme_id)).to eq(false)
    expect(ColorScheme.unscoped.count).to eq(count)
  end

  it "does not overwrite, activate, re-version or delete a hand-edited copy" do
    change = save_change
    theme = change.theme
    theme.set_field(target: :desktop, name: :scss, value: ".hand-edit { margin: 2px; }")
    theme.save!
    original = theme.reload.theme_fields.pluck(:id, :value)
    SystemThemesManager.sync_theme!("horizon")
    expect(theme.reload.theme_fields.pluck(:id, :value)).to eq(original)
    expect(change.theme_unchanged?).to eq(false)
    expect(AppearanceChange.managed_theme_ids).not_to include(theme.id)
    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to fail_a_policy(:theme_unchanged)
    params[:replaces_theme_id] = theme.id
    expect(AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)).to fail_a_policy(
      :supported_base_theme,
    )
    change.discard!
    expect(Theme.exists?(theme.id)).to eq(true)
  end

  it "detects settings, modifiers and component relation edits too" do
    change = save_change
    theme = change.theme
    theme.update_setting(:topic_card_high_context, false)
    expect(change.theme_unchanged?).to eq(false)
    theme.update_setting(:topic_card_high_context, true)
    expect(change.theme_unchanged?).to eq(true)
    theme.theme_modifier_set.update!(serialize_topic_is_hot: false)
    expect(change.theme_unchanged?).to eq(false)
    theme.theme_modifier_set.update!(serialize_topic_is_hot: true)
    expect(change.theme_unchanged?).to eq(true)
    theme.child_themes << Fabricate(:theme, component: true)
    expect(change.theme_unchanged?).to eq(false)
  end

  it "keeps both versions updated so switching back undoes styles, not Horizon releases" do
    first = save_change
    activate(first)
    params[:replaces_theme_id] = first.theme_id
    params[:styles] = { variables: { "--d-border-radius" => "16px" } }
    second = save_change
    activate(second)
    Dir.mktmpdir("horizon-version-update") do |directory|
      FileUtils.cp_r(Rails.root.join("themes/horizon/.").to_s, directory)
      File.write(
        File.join(directory, "common/common.scss"),
        ".new-horizon-release { margin: 2px; }",
      )
      importer = ThemeStore::DirectoryImporter.new(directory)
      ThemeStore::DirectoryImporter
        .stubs(:new)
        .with(Rails.root.join("themes/horizon").to_s)
        .returns(importer)
      SystemThemesManager.sync_theme!("horizon")
    end
    expect(scss(first.theme)).to include(".new-horizon-release", first.css)
    expect(scss(second.theme)).to include(".new-horizon-release", second.css)
    expect(
      AppearanceChange::Revert.call(
        params: {
          appearance_change_id: second.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    expect(SiteSetting.default_theme_id).to eq(first.theme_id)
    expect(first.theme_unchanged?).to eq(true)
  end

  it "requires an explicit detach before editing and leaves detached copies alone" do
    change = save_change
    sign_in(admin)
    put "/admin/themes/#{change.theme_id}.json",
        params: {
          theme: {
            theme_fields: [{ target: "desktop", name: "scss", value: ".manual { margin: 2px; }" }],
          },
        }
    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"].join).to include("Detach")
    put "/admin/themes/#{change.theme_id}.json", params: { theme: { detach_from_horizon: true } }
    expect(response.status).to eq(200)
    expect(change.theme.reload.appearance_sync).to be_nil
    expect(change.theme_unchanged?).to eq(false)
    put "/admin/themes/#{change.theme_id}.json",
        params: {
          theme: {
            theme_fields: [{ target: "desktop", name: "scss", value: ".manual { margin: 2px; }" }],
          },
        }
    expect(response.status).to eq(200)
    original = change.theme.reload.theme_fields.pluck(:id, :value)
    SystemThemesManager.sync_theme!("horizon")
    expect(change.theme.reload.theme_fields.pluck(:id, :value)).to eq(original)
    change.discard!
    expect(Theme.exists?(change.theme_id)).to eq(true)
  end

  it "does not rename a replaced copy that was edited after drafting its successor" do
    first = save_change
    activate(first)
    params[:replaces_theme_id] = first.theme_id
    second = save_change
    first.theme.set_field(target: :desktop, name: :scss, value: ".manual { margin: 2px; }")
    first.theme.save!
    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: second.id,
        },
        guardian: admin.guardian,
      ),
    ).to fail_a_policy(:can_edit_versions)
    expect(first.theme.reload.name).to eq("Rounded Horizon")
    expect(SiteSetting.default_theme_id).to eq(first.theme_id)
  end

  it "keeps syncing retained copies after their appearance record is discarded" do
    change = save_change
    activate(change)
    change.discard!
    expect(change.theme.reload.appearance_sync).to be_present
    expect(AppearanceStyles::SyncedTheme.resync!(change.theme)).to eq(true)
  end

  it "does not turn a component editing restriction into an assistant bypass" do
    Guardian.any_instance.stubs(:can_edit_theme_relations?).returns(false)
    expect(AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)).to fail_a_policy(
      :supported_base_theme,
    )
  end

  it "rejects color-bearing styles before creating any records" do
    params[:styles] = {
      rules: [{ area: "topic_list_item", declarations: { "background" => "var(--secondary)" } }],
    }
    expect {
      result = AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)
      expect(result).to fail_a_step(:check_styles)
    }.not_to change(Theme, :count)
  end

  it "doesn't import copies again when bundled Horizon hasn't changed" do
    change = save_change
    activate(change)

    AppearanceStyles::SyncedTheme.expects(:sync!).never
    SystemThemesManager.sync_theme!("horizon")

    expect(AppearanceStyles::SyncedTheme.unchanged?(change.theme.reload)).to eq(true)
  end

  it "isolates a failed copy and still updates other copies" do
    first = save_change
    second = save_change
    fields = first.theme.theme_fields.order(:id).pluck(:name, :value)
    first.theme.update!(
      appearance_sync:
        first.theme.appearance_sync.merge("css" => "unchecked CSS", "source_digest" => "older"),
    )
    second.theme.update!(
      appearance_sync: second.theme.appearance_sync.merge("source_digest" => "older"),
    )
    Rails.logger.expects(:warn).with(includes("could not sync"))
    SystemThemesManager.sync_theme!("horizon")
    expect(first.theme.reload.theme_fields.order(:id).pluck(:name, :value)).to eq(fields)
    expect(AppearanceStyles::SyncedTheme.unchanged?(second.theme.reload)).to eq(true)
  end

  it "keeps last-known-good copy files when updated source SCSS does not compile" do
    change = save_change
    fields = change.theme.theme_fields.order(:id).pluck(:name, :value)
    Dir.mktmpdir("horizon-invalid-update") do |directory|
      FileUtils.cp_r(Rails.root.join("themes/horizon/.").to_s, directory)
      File.write(
        File.join(directory, "desktop/desktop.scss"),
        ".broken { color: $undefined-horizon-variable; }",
      )
      importer = ThemeStore::DirectoryImporter.new(directory)
      ThemeStore::DirectoryImporter
        .stubs(:new)
        .with(Rails.root.join("themes/horizon").to_s)
        .returns(importer)
      Rails.logger.expects(:warn).with(includes("could not sync"))
      SystemThemesManager.sync_theme!("horizon")
    end
    expect(change.theme.reload.theme_fields.order(:id).pluck(:name, :value)).to eq(fields)
    expect(change.theme_unchanged?).to eq(true)
  end

  it "requires permission on every shared component before attaching it to a copy" do
    component = Fabricate(:theme, component: true)
    Theme.horizon_theme.child_themes << component
    Guardian.any_instance.stubs(:can_edit_theme?).returns(true)
    Guardian.any_instance.stubs(:can_edit_theme?).with(component).returns(false)
    expect(AppearanceChange::DraftTheme.call(params:, guardian: admin.guardian)).to fail_a_policy(
      :supported_base_theme,
    )
  end
end
