# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListAppearanceChanges do
  fab!(:admin)
  fab!(:moderator)

  let(:palettes) { ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c") }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
  end

  def save_change(name)
    AppearanceChange::DraftPalettes.call(
      params: {
        theme_id: Theme.foundation_theme.id,
        name:,
        light_colors: palettes.light,
        dark_colors: palettes.dark,
      },
      guardian: admin.guardian,
    ).appearance_change
  end

  def list(**parameters)
    described_class.new(parameters, bot_user: Discourse.system_user, llm: nil, context:).invoke
  end

  it "lists saved changes newest first, with which is live and how to preview the others" do
    draft = save_change("Draft")
    live = save_change("Live")
    AppearanceChange::Activate.call(
      params: {
        appearance_change_id: live.id,
      },
      guardian: admin.guardian,
    )

    expect(list[:appearance_changes]).to eq(
      [
        {
          id: live.id,
          name: "Live",
          kind: "palettes",
          status: "live",
          theme: "Foundation",
          saved_at: live.created_at.iso8601,
        },
        {
          id: draft.id,
          name: "Draft",
          kind: "palettes",
          status: "draft",
          theme: "Foundation",
          saved_at: draft.created_at.iso8601,
          preview_url: DiscourseAi::Agents::AppearanceAuthoring.preview_url(draft),
        },
      ],
    )
    expect(list(limit: 1)[:appearance_changes].pluck(:id)).to eq([live.id])
  end

  it "is only for administrators" do
    context.user = moderator

    expect(described_class.available_for_context?(context)).to eq(false)
    expect(list).to eq(
      status: "error",
      error: I18n.t("discourse_ai.appearance_authoring.not_allowed"),
    )
  end
end
