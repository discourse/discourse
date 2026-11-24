# frozen_string_literal: true

RSpec.describe AppearanceChange::DraftComponent do
  fab!(:admin)

  let(:horizon) { Theme.horizon_theme }
  let(:styles) { { variables: { "--d-border-radius" => "12px" } } }
  let(:params) { { name: "Rounded", parent_theme_id: horizon.id, styles: } }

  before do
    SystemThemesManager.sync_theme!("horizon")
    horizon.set_default!
  end

  def draft(**overrides)
    result = described_class.call(params: params.merge(overrides), guardian: admin.guardian)
    expect(result).to run_successfully
    result[:appearance_change]
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
    change.reload
  end

  def revert(change)
    expect(
      AppearanceChange::Revert.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    change.reload
  end

  describe ".call" do
    it "saves the styles as a disabled component attached to the theme" do
      change = draft

      component = change.theme
      expect(change).to have_attributes(kind: "component", parent_theme_id: horizon.id)
      expect(component).to have_attributes(component: true, enabled: false, name: "Rounded")
      expect(horizon.reload.child_theme_ids).to include(component.id)
      expect(component.theme_fields.sole.value).to include("--d-border-radius: 12px")
      expect(Theme.transform_ids(horizon.id)).not_to include(component.id)
      expect(SiteSetting.default_theme_id).to eq(horizon.id)
    end

    it "refuses colors, which can't be checked on Horizon yet" do
      result = nil
      expect {
        result =
          described_class.call(
            params:
              params.merge(
                styles: {
                  variables: {
                    "--d-sidebar-background" => "var(--tertiary)",
                  },
                },
              ),
            guardian: admin.guardian,
          )
      }.not_to change { Theme.count }

      expect(result).to fail_a_step(:check_styles)
      expect(AppearanceChange.count).to eq(0)
    end

    it "only adds components to the themes it supports" do
      result =
        described_class.call(
          params: params.merge(parent_theme_id: Theme.foundation_theme.id),
          guardian: admin.guardian,
        )

      expect(result).to fail_a_policy(:supported_parent_theme)
    end

    it "honors restrictions on editing the theme" do
      Guardian.any_instance.stubs(:can_edit_theme?).with(horizon).returns(false)

      expect(described_class.call(params:, guardian: admin.guardian)).to fail_a_policy(
        :supported_parent_theme,
      )
    end

    it "fails with the compile error when the styles don't compile" do
      ThemeField.any_instance.stubs(:error).returns("Undefined variable")

      result = described_class.call(params:, guardian: admin.guardian)

      expect(result).to fail_a_step(:add_styles)
      expect(AppearanceChange.count).to eq(0)
    end

    it "needs administrators" do
      expect(
        described_class.call(params:, guardian: Fabricate(:moderator).guardian),
      ).not_to run_successfully
    end
  end

  describe "making it live and switching back" do
    it "enables the component, then disables it again" do
      change = activate(draft)

      expect(change.theme.enabled).to eq(true)
      expect(change).to be_applied
      expect(Theme.transform_ids(horizon.id)).to include(change.theme_id)
      expect(SiteSetting.default_theme_id).to eq(horizon.id)

      change = revert(change)

      expect(change.theme.reload.enabled).to eq(false)
      expect(change).not_to be_applied
      expect(Theme.transform_ids(horizon.id)).not_to include(change.theme_id)
    end

    it "gives the theme new palettes with the styles, and restores its own when switching back" do
      palettes = ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c")
      original = horizon.reload.attributes.values_at("color_scheme_id", "dark_color_scheme_id")
      change = draft(light_colors: palettes.light, dark_colors: palettes.dark)

      activate(change)
      expect(horizon.reload).to have_attributes(
        color_scheme_id: change.light_color_scheme_id,
        dark_color_scheme_id: change.dark_color_scheme_id,
      )

      revert(change)
      expect(horizon.reload.attributes.values_at("color_scheme_id", "dark_color_scheme_id")).to eq(
        original,
      )
    end

    it "keeps a live, a previous and a draft version, and switches back to the previous one" do
      first = activate(draft)
      second = draft(replaces_theme_id: first.theme_id)
      expect(second.theme.name).to eq("Rounded (draft)")

      activate(second)
      expect(first.theme.reload).to have_attributes(enabled: false, name: "Rounded (previous)")
      expect(second.theme.reload).to have_attributes(enabled: true, name: "Rounded")

      third = activate(draft(replaces_theme_id: second.theme_id))
      expect(Theme.exists?(first.theme_id)).to eq(false)
      expect(second.theme.reload).to have_attributes(enabled: false, name: "Rounded (previous)")

      revert(third)
      expect(second.theme.reload).to have_attributes(enabled: true, name: "Rounded")
      expect(third.theme.reload).to have_attributes(enabled: false, name: "Rounded (draft)")
    end

    it "keeps the component on Horizon when core updates Horizon" do
      change = activate(draft)

      SystemThemesManager.sync_theme!("horizon")

      expect(horizon.reload.child_theme_ids).to include(change.theme_id)
      expect(change.reload).to be_applied
      expect(Theme.transform_ids(horizon.id)).to include(change.theme_id)
    end

    it "only makes new versions of components nobody has changed" do
      first = activate(draft)
      first.theme.set_field(target: :common, name: :scss, value: "body { margin: 1px; }")
      first.theme.save!

      result =
        described_class.call(
          params: params.merge(replaces_theme_id: first.theme_id),
          guardian: admin.guardian,
        )
      expect(result).to fail_a_policy(:replaceable_component)
    end

    it "does not turn other components off or on when the administrator can't edit them" do
      first = activate(draft)
      second = draft(name: "Other")
      Guardian.any_instance.stubs(:can_edit_theme?).returns(true)
      Guardian.any_instance.stubs(:can_edit_theme?).with(first.theme).returns(false)

      expect(
        AppearanceChange::Activate.call(
          params: {
            appearance_change_id: second.id,
          },
          guardian: admin.guardian,
        ),
      ).to fail_a_policy(:can_edit_replaced_components)
      expect(first.theme.reload.enabled).to eq(true)
      expect(second.theme.reload.enabled).to eq(false)

      Guardian.any_instance.unstub(:can_edit_theme?)
      activate(second)
      Guardian.any_instance.stubs(:can_edit_theme?).returns(true)
      Guardian.any_instance.stubs(:can_edit_theme?).with(first.theme).returns(false)

      expect(
        AppearanceChange::Revert.call(
          params: {
            appearance_change_id: second.id,
          },
          guardian: admin.guardian,
        ),
      ).to fail_a_policy(:can_edit_restored_components)
      expect(second.theme.reload.enabled).to eq(true)
      expect(first.theme.reload.enabled).to eq(false)
    end

    it "does not make a component live once it's no longer attached to the theme" do
      change = draft
      horizon.child_themes.delete(change.theme)

      expect(
        AppearanceChange::Activate.call(
          params: {
            appearance_change_id: change.id,
          },
          guardian: admin.guardian,
        ),
      ).to fail_a_policy(:attached_to_parent)
    end
  end

  describe "components someone changed" do
    it "leaves an earlier component someone edited on when a new one goes live" do
      first = activate(draft)
      first.theme.set_field(target: :common, name: :header, value: "<div>Hi</div>")
      first.theme.save!

      second = draft(name: "Bigger")
      expect(second.enabled_sibling_components).to be_empty
      activate(second)

      expect(first.theme.reload.enabled).to eq(true)
    end

    it "treats a component someone added to another theme as theirs" do
      first = activate(draft)
      other_theme = Fabricate(:theme)
      other_theme.add_relative_theme!(:child, first.theme)

      expect(first.reload.theme_unchanged?).to eq(false)
      expect(AppearanceChange.managed_component_ids).not_to include(first.theme_id)

      activate(draft(name: "Bigger"))
      expect(first.theme.reload.enabled).to eq(true)

      first.discard!
      expect(Theme.exists?(first.theme_id)).to eq(true)
    end
  end

  describe ".managed_component_ids" do
    it "lists unchanged components with the same number of queries however many there are" do
      first = draft
      queries = track_sql_queries { AppearanceChange.managed_component_ids }.size
      others = [draft(name: "Two"), draft(name: "Three")]

      ids = nil
      expect(track_sql_queries { ids = AppearanceChange.managed_component_ids }.size).to eq(queries)
      expect(ids).to contain_exactly(first.theme_id, *others.map(&:theme_id))
    end
  end

  describe "cleaning up" do
    it "removes an abandoned draft's component" do
      change = draft
      change.discard!

      expect(Theme.exists?(change.theme_id)).to eq(false)
      expect(horizon.reload.child_theme_ids).not_to include(change.theme_id)
    end

    it "keeps a component someone enabled or edited" do
      change = draft
      change.theme.update!(enabled: true)
      change.discard!

      expect(Theme.exists?(change.theme_id)).to eq(true)
    end
  end

  it "keeps the design wizard available while the theme only has assistant components" do
    activate(draft)

    json = CurrentUserSerializer.new(admin, scope: admin.guardian, root: false).as_json
    expect(json[:can_run_design_wizard]).to eq(true)
  end
end
