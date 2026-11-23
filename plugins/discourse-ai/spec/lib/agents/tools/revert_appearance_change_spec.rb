# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::RevertAppearanceChange do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  fab!(:light_palette) do
    Fabricate(
      :color_scheme,
      color_scheme_colors: [
        Fabricate.build(:color_scheme_color, name: "tertiary", hex: "a84300", color_scheme: nil),
      ],
    )
  end
  fab!(:dark_palette, :color_scheme)

  let(:appearance_change) { make_live(palette_change(site_settings: { heading_font: "lora" })) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) { build_tool(appearance_change) }

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
  end

  def palette_change(theme: Theme.foundation_theme, name: "Acme", site_settings: {})
    Fabricate(
      :appearance_change,
      name:,
      theme:,
      user: admin,
      light_color_scheme: light_palette,
      dark_color_scheme: dark_palette,
      site_settings:,
    )
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
    change.reload
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
    link_color = light_palette.resolved_colors.fetch("tertiary")

    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_title).to eq("Switch back from: Acme")
    expect(tool.approval_changes).to include(
      a_hash_including(
        label: "Links and buttons",
        before: "##{link_color}",
        before_color: link_color,
      ),
      { label: "Heading font", before: "Lora", after: "Inter" },
    )
  end

  it "restores the palettes and fonts it replaced once approved" do
    original_palette_ids = foundation_palette_ids
    item = build_reviewable(appearance_change)

    expect { item.perform(other_admin, :approve) }.to change { foundation_palette_ids }.to(
      original_palette_ids,
    ).and change { SiteSetting.heading_font }.from("lora").to("inter")
  end

  it "tells the administrator to refresh the page after switching back" do
    result = approve_as(other_admin, build_reviewable(appearance_change))

    expect(result[:status]).to eq("success")
    expect(result[:message]).to include("refresh the page")
  end

  it "makes the previous default theme the default again once approved" do
    theme_change =
      Fabricate(
        :theme_appearance_change,
        name: "Acme",
        theme:
          Fabricate(
            :theme,
            name: "Acme",
            color_scheme: light_palette,
            dark_color_scheme: dark_palette,
          ),
        light_color_scheme: light_palette,
        dark_color_scheme: dark_palette,
        user: admin,
      )
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
    revert = tool

    expect { expect(revert.invoke).to eq(error(:approval_required)) }.not_to change {
      Theme.foundation_theme.reload.color_scheme_id
    }
  end

  it "only switches back the change that was approved" do
    appearance_change
    other_change = palette_change(theme: Theme.horizon_theme, name: "Other")
    make_live(other_change)
    item = build_reviewable(other_change)

    expect {
      expect(approve_as(other_admin, item)).to eq(error(:approval_required))
    }.not_to change { Theme.foundation_theme.reload.color_scheme_id }
  end

  it "refuses a change that isn't live" do
    draft = palette_change(name: "Draft")

    expect(build_tool(draft).validation_error).to eq(error(:not_live))
  end

  it "refuses to switch back when what the change replaced is gone" do
    previous_palette = Fabricate(:color_scheme)
    theme = Fabricate(:theme, color_scheme: previous_palette)
    theme_palettes = palette_change(theme:, name: "Brand palettes")
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
