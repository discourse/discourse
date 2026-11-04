# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::RevertAppearanceChange do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  let(:palettes) { ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c") }
  let(:appearance_change) { save_change(theme_id: Theme.foundation_theme.id) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) { build_tool(appearance_change) }
  let!(:original_palette_ids) { foundation_palette_ids }

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
    make_live(appearance_change)
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

  def foundation_palette_ids
    Theme.foundation_theme.reload.slice(:color_scheme_id, :dark_color_scheme_id)
  end

  def make_live(change)
    AppearanceChange::Activate.call(
      params: {
        appearance_change_id: change.id,
      },
      guardian: admin.guardian,
    )
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

  it "needs approval and shows what switching back restores" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_title).to eq("Switch back from: Acme")
    expect(tool.approval_changes).to include(
      a_hash_including(
        label: "Links and buttons",
        before: "##{palettes.light["tertiary"]}",
        before_color: palettes.light["tertiary"],
      ),
      { label: "Heading font", before: "Lora", after: "Inter" },
    )
  end

  it "restores the palettes and fonts it replaced once approved" do
    item = build_reviewable(appearance_change)

    expect { item.perform(other_admin, :approve) }.to change { foundation_palette_ids }.to(
      original_palette_ids,
    ).and change { SiteSetting.heading_font }.from("lora").to("inter")
  end

  it "makes the previous default theme the default again once approved" do
    theme_change = save_change(service: AppearanceChange::DraftTheme)
    make_live(theme_change)
    item = build_reviewable(theme_change)

    expect(build_tool(theme_change).approval_changes).to include(
      { label: "Default theme", before: "Acme", after: "Foundation" },
    )
    expect { item.perform(other_admin, :approve) }.to change { SiteSetting.default_theme_id }.to(
      Theme.foundation_theme.id,
    )
  end

  it "doesn't change anything without approval" do
    expect { expect(tool.invoke).to eq(error(:approval_required)) }.not_to change {
      Theme.foundation_theme.reload.color_scheme_id
    }
  end

  it "only switches back the change that was approved" do
    other_change = save_change(theme_id: Theme.horizon_theme.id, name: "Other")
    make_live(other_change)
    item = build_reviewable(other_change)

    expect {
      expect(approve_as(other_admin, item)).to eq(error(:approval_required))
    }.not_to change { Theme.foundation_theme.reload.color_scheme_id }
  end

  it "refuses a change that isn't live" do
    draft = save_change(theme_id: Theme.foundation_theme.id, name: "Draft")

    expect(build_tool(draft).validation_error).to eq(error(:not_live))
  end

  it "refuses to switch back when what the change replaced is gone" do
    previous_palette = Fabricate(:color_scheme)
    theme = Fabricate(:theme, color_scheme: previous_palette)
    theme_palettes = save_change(theme_id: theme.id, name: "Brand palettes")
    make_live(theme_palettes)
    previous_palette.destroy!

    expect(build_tool(theme_palettes).validation_error).to eq(error(:cannot_restore))
  end

  it "only lets administrators approve it" do
    item = build_reviewable(appearance_change)

    expect { expect(approve_as(moderator, item)).to eq(error(:not_allowed)) }.not_to change {
      Theme.foundation_theme.reload.color_scheme_id
    }
  end
end
