# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ActivateAppearanceChange do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  let(:palettes) { ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c") }
  let(:appearance_change) { save_change(theme_id: Theme.foundation_theme.id) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) { build_tool(appearance_change) }

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
  end

  def save_change(service: AppearanceChange::DraftPalettes, **params)
    service.call(
      params: {
        name: "Acme",
        light_colors: palettes.light,
        dark_colors: palettes.dark,
        site_settings: {
          heading_font: "lora",
        },
        **params,
      },
      guardian: admin.guardian,
    ).appearance_change
  end

  def build_tool(change)
    described_class.new(
      { appearance_change_id: change.id },
      bot_user: Discourse.system_user,
      llm: nil,
      context:,
    )
  end

  def build_reviewable(change)
    action =
      AiToolAction.create!(
        tool_name: described_class.name,
        tool_parameters: {
          appearance_change_id: change.id,
        },
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    item =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    item.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    item
  end

  def approve_as(approver, reviewable)
    context.user = approver
    context.reviewable_id = reviewable.id
    tool.invoke
  end

  def error(key)
    { status: "error", error: I18n.t("discourse_ai.appearance_authoring.#{key}") }
  end

  it "needs approval and shows what would change, with a link to preview it first" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_title).to eq("Make live: Acme")
    expect(tool.approval_changes).to include(
      a_hash_including(
        label: "Links and buttons",
        after: "##{palettes.light["tertiary"]}",
        after_color: palettes.light["tertiary"],
      ),
      { label: "Heading font", before: "Inter", after: "Lora" },
    )
    expect(tool.approval_details).to include(
      DiscourseAi::Agents::AppearanceAuthoring.preview_url(appearance_change),
    )
    expect(tool.approval_parameters).to be_empty
  end

  it "makes the palettes and fonts live once approved, as the approver" do
    item = build_reviewable(appearance_change)

    expect { item.perform(other_admin, :approve) }.to change { SiteSetting.heading_font }.to("lora")
    expect(Theme.foundation_theme.reload).to have_attributes(
      color_scheme_id: appearance_change.light_color_scheme_id,
      dark_color_scheme_id: appearance_change.dark_color_scheme_id,
    )
    expect(
      UserHistory.find_by(
        action: UserHistory.actions[:change_site_setting],
        subject: "heading_font",
      ),
    ).to have_attributes(acting_user_id: other_admin.id)
  end

  it "makes a new theme the default once approved" do
    theme_change = save_change(service: AppearanceChange::DraftTheme)
    item = build_reviewable(theme_change)

    expect(build_tool(theme_change).approval_changes).to include(
      { label: "Default theme", before: "Foundation", after: "Acme" },
    )
    expect { item.perform(other_admin, :approve) }.to change { SiteSetting.default_theme_id }.to(
      theme_change.theme_id,
    )
  end

  it "doesn't change anything without approval" do
    expect { expect(tool.invoke).to eq(error(:approval_required)) }.not_to change {
      Theme.foundation_theme.reload.color_scheme_id
    }
  end

  it "only makes live the change that was approved" do
    approved_change = save_change(theme_id: Theme.foundation_theme.id, name: "Other")
    item = build_reviewable(approved_change)

    expect {
      expect(approve_as(other_admin, item)).to eq(error(:approval_required))
    }.not_to change { Theme.foundation_theme.reload.color_scheme_id }
  end

  it "refuses a change that is already live" do
    AppearanceChange::Activate.call(
      params: {
        appearance_change_id: appearance_change.id,
      },
      guardian: admin.guardian,
    )

    expect(tool.validation_error).to eq(error(:already_live))
  end

  it "checks access again when the change is approved" do
    plugin = Plugin::Instance.new
    modifier =
      proc do |decision, request|
        request.phase == :approval ? decision.deny!("Appearance changes are turned off") : decision
      end
    plugin.register_modifier(:admin_assistant_feature_access, &modifier)
    item = build_reviewable(appearance_change)

    expect(tool.validation_error).to be_nil
    expect {
      expect(approve_as(other_admin, item)).to eq(
        status: "error",
        error: "Appearance changes are turned off",
      )
    }.not_to change { Theme.foundation_theme.reload.color_scheme_id }
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_feature_access, &modifier)
  end

  it "only lets administrators approve it" do
    item = build_reviewable(appearance_change)

    expect { expect(approve_as(moderator, item)).to eq(error(:not_allowed)) }.not_to change {
      Theme.foundation_theme.reload.color_scheme_id
    }
  end
end
