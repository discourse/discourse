# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SaveAppearanceChange do
  # saving, making live and switching back a component for Horizon
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:ai_agent)

  let(:horizon) { Theme.horizon_theme }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:authoring) { DiscourseAi::Agents::AppearanceAuthoring }
  let(:draft_attributes) do
    {
      kind: "component",
      parent_theme_id: horizon.id,
      name: "Rounded",
      site_settings: {
      },
      styles: {
        "variables" => {
          "--d-sys-border-radius-md" => "12px",
        },
      },
    }
  end
  let(:token) { authoring::Draft.sign(draft_attributes, user: admin) }

  before do
    enable_current_plugin
    SystemThemesManager.sync_theme!("horizon")
    horizon.set_default!
  end

  def build_tool(tool_class, parameters)
    tool_class.new(parameters, bot_user: Discourse.system_user, llm: nil, context:)
  end

  def approve(tool_class, parameters)
    tool = build_tool(tool_class, parameters)
    expect(tool.validation_error).to be_nil
    action =
      AiToolAction.create!(
        tool_name: tool_class.name,
        tool_parameters: tool.parameters,
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    context.user = other_admin
    context.reviewable_id = reviewable.id
    build_tool(tool_class, parameters).invoke.tap do
      context.user = admin
      context.reviewable_id = nil
    end
  end

  it "saves the styles as a disabled component, then turns it on and off, each once approved" do
    save_tool = build_tool(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token)
    expect(save_tool.approval_title).to eq("Save styles: Rounded")
    expect(save_tool.approval_details).to eq(
      I18n.t("discourse_ai.ai_bot.chat_tool_approval.save_appearance_details.component"),
    )
    expect(save_tool.approval_changes).to contain_exactly(
      a_hash_including(label: "--d-sys-border-radius-md", after: "12px"),
    )

    saved = approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token)
    change = AppearanceChange.last
    expect(saved).to include(status: "success", appearance_change_id: change.id)
    expect(change).to have_attributes(kind: "component", parent_theme_id: horizon.id)
    expect(change.theme.enabled).to eq(false)

    query = Rack::Utils.parse_query(URI(saved[:preview_url]).query)
    expect(query).to include(
      "preview_theme_id" => horizon.id.to_s,
      "preview_component_ids" => change.theme_id.to_s,
    )

    activate_tool =
      build_tool(
        DiscourseAi::Agents::Tools::ActivateAppearanceChange,
        appearance_change_id: change.id,
      )
    expect(activate_tool.approval_changes).to include(
      a_hash_including(label: "--d-sys-border-radius-md", after: "12px"),
      { label: "Component: Rounded", before: "Off", after: "On" },
    )
    expect(activate_tool.approval_details).to include(horizon.name, saved[:preview_url])

    expect(
      approve(
        DiscourseAi::Agents::Tools::ActivateAppearanceChange,
        appearance_change_id: change.id,
      ),
    ).to include(status: "success")
    expect(change.theme.reload.enabled).to eq(true)
    expect(SiteSetting.default_theme_id).to eq(horizon.id)

    revert_tool =
      build_tool(
        DiscourseAi::Agents::Tools::RevertAppearanceChange,
        appearance_change_id: change.id,
      )
    expect(revert_tool.approval_changes).to eq(
      [{ label: "Component: Rounded", before: "On", after: "Off" }],
    )
    expect(
      approve(DiscourseAi::Agents::Tools::RevertAppearanceChange, appearance_change_id: change.id),
    ).to include(status: "success")
    expect(change.theme.reload.enabled).to eq(false)
  end

  it "saves a component without palettes, and makes it live, on a site that can't create palettes" do
    plugin = Plugin::Instance.new
    modifier =
      proc do |decision, request|
        decision.deny!("No new palettes here.") if request.feature == :palette_authoring
        decision
      end
    plugin.register_modifier(:admin_assistant_feature_access, &modifier)

    expect(
      approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token),
    ).to include(status: "success")
    change = AppearanceChange.last
    expect(
      approve(
        DiscourseAi::Agents::Tools::ActivateAppearanceChange,
        appearance_change_id: change.id,
      ),
    ).to include(status: "success")
    expect(change.theme.reload.enabled).to eq(true)
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_feature_access, &modifier)
  end

  it "previews a new version without the version it replaces" do
    approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token)
    first = AppearanceChange.last
    approve(DiscourseAi::Agents::Tools::ActivateAppearanceChange, appearance_change_id: first.id)
    draft_attributes[:replaces_theme_id] = first.theme_id
    second_token = authoring::Draft.sign(draft_attributes, user: admin)

    saved = approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: second_token)

    query = Rack::Utils.parse_query(URI(saved[:preview_url]).query)
    expect(query).to include(
      "preview_component_ids" => AppearanceChange.last.theme_id.to_s,
      "preview_hide_component_ids" => first.theme_id.to_s,
    )
  end

  it "does not make a component live once someone has edited it" do
    approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token)
    change = AppearanceChange.last
    change.theme.set_field(target: :common, name: :scss, value: "body { margin: 1px; }")
    change.theme.save!

    expect(
      build_tool(
        DiscourseAi::Agents::Tools::ActivateAppearanceChange,
        appearance_change_id: change.id,
      ).validation_error,
    ).to eq(status: "error", error: I18n.t("discourse_ai.appearance_authoring.theme_changed"))
  end

  it "refuses a draft for a theme that doesn't take components" do
    draft_attributes[:parent_theme_id] = Theme.foundation_theme.id

    result = approve(DiscourseAi::Agents::Tools::SaveAppearanceChange, draft_token: token)

    expect(result[:status]).to eq("error")
    expect(AppearanceChange.count).to eq(0)
  end
end
