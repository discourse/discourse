# frozen_string_literal: true

describe DiscourseMcp::Tools::UpdateTheme do
  fab!(:admin)
  fab!(:user)
  fab!(:theme) { Fabricate(:theme, user_selectable: true) }
  fab!(:parent, :theme)
  fab!(:existing_component) { Fabricate(:theme, component: true) }

  def invoke(arguments = {}, actor: admin, **fields)
    described_class.call(
      arguments: { "theme_id" => theme.id }.merge(arguments).merge(fields),
      request_context:
        instance_double(
          DiscourseMcp::RequestContext,
          content_policy: DiscourseMcp::ContentPolicy.new([]),
          guardian: actor.guardian,
        ),
    )[
      :structuredContent
    ][
      :theme
    ]
  end

  describe ".call" do
    it "converts and attaches in place, preserving code and the parent's other components" do
      parent.set_default!
      parent.child_themes << existing_component
      theme.set_field(target: "common", name: "scss", value: ".d-header { color: red; }")
      theme.save!
      revision = DiscourseMcp::Tools::ThemeSupport.code_revision(theme)

      result = invoke("component" => true, "parent_theme_ids" => [parent.id])
      expect(theme.reload.component?).to eq(true)
      expect(theme.user_selectable).to eq(false)
      expect(result[:id]).to eq(theme.id)
      expect(result[:code_revision]).to eq(revision)
      expect(result[:activation][:applies_to_default_theme]).to eq(true)
      expect(parent.reload.child_theme_ids).to contain_exactly(existing_component.id, theme.id)

      result = invoke("component" => false)
      expect(theme.reload.component?).to eq(false)
      expect(theme.parent_theme_ids).to be_empty
      expect(result[:activation][:applies_to_default_theme]).to eq(false)
    end

    it "converts a component into a default theme in one update" do
      theme.update!(component: true)
      result = invoke("component" => false, "default" => true)
      expect(theme.reload.component?).to eq(false)
      expect(theme.default?).to eq(true)
      expect(result[:activation][:applies_to_default_theme]).to eq(true)
    end

    it "reports enabled but unattached components as inactive on the default theme" do
      result = invoke("component" => true)
      expect(result[:enabled]).to eq(true)
      expect(result[:activation][:applies_to_default_theme]).to eq(false)
    end

    it "rolls back conversion when attachment fails and explains the required types" do
      expect {
        invoke("component" => true, "parent_theme_ids" => [existing_component.id])
      }.to raise_error(DiscourseMcp::ToolError, /standalone theme/)
      expect(theme.reload.component?).to eq(false)
      expect(theme.user_selectable).to eq(true)
    end

    it "protects the default theme and denies non-admin conversion" do
      expect { invoke({ "component" => true }, actor: user) }.to raise_error(
        Discourse::InvalidAccess,
      )
      theme.set_default!
      expect { invoke("component" => true) }.to raise_error(DiscourseMcp::ToolError)
      expect(theme.reload.component?).to eq(false)
      expect(SiteSetting.default_theme_id).to eq(theme.id)
    end

    it "requires permission to detach a component during conversion" do
      theme.child_themes << existing_component
      plugin = Plugin::Instance.new
      modifier = proc { |allowed, _guardian, target| allowed && target.id != existing_component.id }
      plugin.register_modifier(:user_guardian_can_edit_theme, &modifier)

      expect { invoke("component" => true) }.to raise_error(Discourse::InvalidAccess)
      expect(theme.reload.component?).to eq(false)
      expect(theme.child_theme_ids).to eq([existing_component.id])
    ensure
      if plugin
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :user_guardian_can_edit_theme,
          &modifier
        )
      end
    end

    it "rolls back conversion when the resulting theme is forbidden by a plugin policy" do
      parent.set_default!
      theme.update!(component: true)
      theme.set_field(target: :common, name: "scss", value: "body { color: red; }")
      theme.save!
      original_revision = DiscourseMcp::Tools::ThemeSupport.code_revision(theme)
      original_audit_count = UserHistory.where(acting_user_id: admin.id).count
      plugin = Plugin::Instance.new
      modifier = proc { |allowed, _guardian, target| allowed && target.component? }
      plugin.register_modifier(:user_guardian_can_edit_theme, &modifier)

      expect do
        invoke(
          "component" => false,
          "default" => true,
          "theme_fields" => [
            {
              "target" => "extra_js",
              "name" => "discourse/api-initializers/restricted.js",
              "value" => "document.documentElement.dataset.restricted = 'yes';",
            },
          ],
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(theme.reload.component?).to eq(true)
      expect(SiteSetting.default_theme_id).to eq(parent.id)
      expect(DiscourseMcp::Tools::ThemeSupport.code_revision(theme)).to eq(original_revision)
      expect(UserHistory.where(acting_user_id: admin.id).count).to eq(original_audit_count)
    ensure
      if plugin
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :user_guardian_can_edit_theme,
          &modifier
        )
      end
    end
  end
end
