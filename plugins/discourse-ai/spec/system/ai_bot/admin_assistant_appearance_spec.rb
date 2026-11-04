# frozen_string_literal: true

RSpec.describe "Admin Assistant appearance changes" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
      allow_chat_direct_messages: true,
    ).tap(&:create_user!)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel) { Fabricate(:direct_message_channel, users: [admin, ai_agent.user]) }
  let(:theme) { Theme.foundation_theme }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:approve_label) { I18n.t("discourse_ai.ai_bot.chat_tool_approval.approve_label") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    theme.set_default!
    sign_in(admin)
  end

  # Posts the approval card the assistant posts when it calls a tool that
  # needs approval.
  def post_approval_card(tool_class, parameters)
    tool = tool_class.new(parameters, bot_user: ai_agent.user, llm: nil, context:)
    expect(tool.validation_error).to be_nil

    action =
      AiToolAction.create!(
        tool_name: tool.name,
        tool_parameters: tool.parameters,
        ai_agent:,
        bot_user_id: ai_agent.user_id,
      )
    source_message = Fabricate(:chat_message, chat_channel: channel, user: admin)
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: ai_agent.user,
        reviewable_by_moderator: true,
        payload: {
          chat_message_id: source_message.id,
        },
      )
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    Fabricate(
      :chat_message,
      chat_channel: channel,
      user: ai_agent.user,
      message: tool.approval_details,
      blocks:
        DiscourseAi::AiBot::ChatToolApproval.pending_blocks(
          reviewable.id,
          info: {
            summary: tool.approval_title,
            changes: tool.approval_changes,
            details: tool.approval_details,
            question: tool.approval_question,
            parameters: tool.approval_parameters,
          },
        ),
    )
  end

  # Giving a theme new palettes recompiles its stylesheets during the request,
  # which takes longer than clicks normally wait for the page to settle. That
  # wait reads the global setting, which `using_wait_time` doesn't change.
  def approve_with_stylesheet_compilation
    wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 30
    click_button(approve_label)
  ensure
    Capybara.default_max_wait_time = wait_time
  end

  it "saves new palettes to preview, then makes them live, each once approved" do
    generated =
      DiscourseAi::Agents::Tools::GenerateAppearanceChange.new(
        { name: "Acme", brand_color: "#e8590c" },
        bot_user: ai_agent.user,
        llm: nil,
        context:,
      ).invoke
    post_approval_card(
      DiscourseAi::Agents::Tools::SaveAppearanceChange,
      { draft_token: generated[:draft_token] },
    )

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-confirmation__title", text: "Save palettes: Acme")
    expect(page).to have_css(".chat-confirmation__change", text: "Links and buttons")
    expect(page).to have_css(".chat-confirmation__after .chat-confirmation__color")
    expect(page.html).not_to include(generated[:draft_token])

    click_button(approve_label)
    expect(page).to have_text("Approved by @#{admin.username}")
    appearance_change = AppearanceChange.last
    expect(appearance_change).to have_attributes(name: "Acme", kind: "palettes", activated_at: nil)
    expect(theme.reload.color_scheme_id).not_to eq(appearance_change.light_color_scheme_id)

    visit(URI(DiscourseAi::Agents::AppearanceAuthoring.preview_url(appearance_change)).request_uri)
    expect(page).to have_css(
      "link.light-scheme[data-scheme-id='#{appearance_change.light_color_scheme_id}']",
      visible: false,
    )

    post_approval_card(
      DiscourseAi::Agents::Tools::ActivateAppearanceChange,
      { appearance_change_id: appearance_change.id },
    )
    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-confirmation__title", text: "Make live: Acme")

    approve_with_stylesheet_compilation
    expect(page).to have_text("Approved by @#{admin.username}", count: 2)
    expect(theme.reload).to have_attributes(
      color_scheme_id: appearance_change.light_color_scheme_id,
      dark_color_scheme_id: appearance_change.dark_color_scheme_id,
    )

    visit("/")
    expect(page).to have_css(
      "link.light-scheme[data-scheme-id='#{appearance_change.light_color_scheme_id}']",
      visible: false,
    )
  end
end
