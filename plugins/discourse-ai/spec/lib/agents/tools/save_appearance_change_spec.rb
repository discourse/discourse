# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SaveAppearanceChange do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  let(:palettes) { ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c") }
  let(:kind) { "palettes" }
  let(:draft_attributes) do
    {
      kind:,
      theme_id: (Theme.foundation_theme.id if kind == "palettes"),
      name: "Acme",
      light_colors: palettes.light,
      dark_colors: palettes.dark,
      site_settings: {
        "heading_font" => "lora",
      },
    }.compact
  end
  let(:token) do
    DiscourseAi::Agents::AppearanceAuthoring::Draft.sign(draft_attributes, user: admin)
  end
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) do
    described_class.new({ draft_token: token }, bot_user: Discourse.system_user, llm: nil, context:)
  end

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
  end

  def build_reviewable(draft_token: token, requester_id: admin.id)
    action =
      AiToolAction.create!(
        tool_name: described_class.name,
        tool_parameters: {
          draft_token:,
          requester_id:,
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

  it "needs approval and shows the colors and fonts it would save, without the draft token" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_title).to eq("Save palettes: Acme")
    expect(tool.approval_changes).to include(
      a_hash_including(
        label: "Links and buttons",
        after: "##{palettes.light["tertiary"]}",
        after_color: palettes.light["tertiary"],
      ),
      { label: "Heading font", before: "Inter", after: "Lora" },
    )
    expect(tool.approval_parameters).to be_empty
    expect([tool.approval_title, tool.approval_details, tool.details].join).not_to include(token)
  end

  it "compares new palettes with their own theme's, even after another theme became the default" do
    theme_colors = ->(theme) do
      DiscourseAi::Agents::AppearanceAuthoring.theme_palettes(theme)[:light]["tertiary"]
    end
    Theme.horizon_theme.set_default!

    expect(theme_colors.(Theme.horizon_theme)).not_to eq(theme_colors.(Theme.foundation_theme))
    expect(tool.approval_changes).to include(
      a_hash_including(
        label: "Links and buttons",
        before: "##{theme_colors.(Theme.foundation_theme)}",
      ),
    )
  end

  it "ties the approval to the administrator who asked for the draft" do
    expect(tool.validation_error).to be_nil
    expect(tool.parameters[:requester_id]).to eq(admin.id)
  end

  it "saves the palettes without changing the site once approved, and links to a preview" do
    reviewable = build_reviewable
    result = nil

    expect { result = approve_as(other_admin, reviewable) }.to change { AppearanceChange.count }.by(
      1,
    ).and not_change { Theme.foundation_theme.reload.color_scheme_id }

    appearance_change = AppearanceChange.last
    expect(appearance_change).to have_attributes(
      kind: "palettes",
      name: "Acme",
      theme: Theme.foundation_theme,
      user: other_admin,
      site_settings: {
        "heading_font" => "lora",
      },
    )
    expect(appearance_change.light_color_scheme.resolved_colors).to include(
      "tertiary" => palettes.light["tertiary"],
    )
    expect(result).to eq(
      status: "success",
      appearance_change_id: appearance_change.id,
      name: "Acme",
      preview_url:
        "#{Discourse.base_url}/?preview_color_scheme_id=#{appearance_change.light_color_scheme_id}&preview_dark_color_scheme_id=#{appearance_change.dark_color_scheme_id}",
      message: I18n.t("discourse_ai.appearance_authoring.saved"),
    )
  end

  it "saves once the review item is approved" do
    reviewable = build_reviewable

    expect { reviewable.perform(other_admin, :approve) }.to change { AppearanceChange.count }.by(1)
    expect(AppearanceChange.last.user).to eq(other_admin)
  end

  context "with a new theme" do
    let(:kind) { "theme" }

    it "saves the theme without making it the default" do
      result = nil

      expect { result = approve_as(other_admin, build_reviewable) }.to change { Theme.count }.by(1)

      theme = AppearanceChange.last.theme
      expect(theme).to have_attributes(name: "Acme", default?: false, user_selectable: false)
      expect(result[:preview_url]).to eq("#{Discourse.base_url}/?preview_theme_id=#{theme.id}")
    end
  end

  it "doesn't save anything without approval" do
    expect(tool.invoke).to eq(
      status: "error",
      error: I18n.t("discourse_ai.appearance_authoring.approval_required"),
    )
    expect(AppearanceChange.count).to eq(0)
  end

  it "saves a draft only once" do
    approve_as(other_admin, build_reviewable)

    expect(approve_as(other_admin, build_reviewable)).to eq(
      status: "error",
      error: I18n.t("discourse_ai.appearance_authoring.draft_used"),
    )
    expect(AppearanceChange.count).to eq(1)
  end

  it "rejects drafts it can't trust" do
    forged =
      described_class.new(
        { draft_token: "appearance_draft_#{SecureRandom.hex(16)}" },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )
    expect(forged.validation_error[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.invalid_draft"),
    )

    context.user = other_admin
    expect(tool.validation_error[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.not_allowed"),
    )

    expect(approve_as(other_admin, build_reviewable(requester_id: other_admin.id))).to eq(
      status: "error",
      error: I18n.t("discourse_ai.appearance_authoring.approval_required"),
    )
    expect(AppearanceChange.count).to eq(0)
  end

  it "only lets administrators approve it" do
    expect(approve_as(moderator, build_reviewable)[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.not_allowed"),
    )
    expect(AppearanceChange.count).to eq(0)
  end
end
