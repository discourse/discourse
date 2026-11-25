# frozen_string_literal: true

RSpec.describe "Workflow chat", if: defined?(Chat) do
  fab!(:admin)
  fab!(:member, :user)
  fab!(:group)

  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:welcome_message) { "Welcome to the help desk." }
  let(:start_chat) { I18n.t("js.discourse_workflows.chat_conversation.start") }
  let(:workflow) do
    graph =
      build_workflow_graph do |builder|
        builder.node(
          "chat",
          "trigger:workflow_chat",
          configuration: {
            chat_title: "Help desk",
            welcome_message:,
            group_ids: [group.id],
          },
        )
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end
  let(:launch_path) { "/workflows/chat/#{workflow.id}/chat" }

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:logged_in_users]
    group.add(member)
  end

  it "lets an admin test the draft from the editor, which also shows the launch URL" do
    sign_in(admin)
    editor_page.visit(workflow.id)
    find(".workflow-rete-node").hover
    test_label = I18n.t("js.discourse_workflows.manual_trigger.test_in_new_tab")
    test_chat = window_opened_by { find("button[aria-label='#{test_label}']").click }

    within_window(test_chat) do
      expect(page).to have_current_path(%r{\A/chat/c/[^/]+/\d+\z})
      expect(page).to have_text(I18n.t("discourse_workflows.workflow_chat.draft_notice"))
    end

    editor_page.double_click_node(0)

    expect(editor_page).to have_launch_url(launch_path)
  end

  it "starts a chat from a link in a post once the member confirms" do
    sign_in(member)
    post = Fabricate(:post, raw: "[Start a chat](#{launch_path})")
    topic_page = PageObjects::Pages::Topic.new
    topic_page.visit_topic(post.topic)

    topic_page.within_post(post) { click_link("Start a chat") }

    expect(page).to have_button(start_chat)
    expect(page).to have_current_path(launch_path)

    click_button(start_chat)

    expect(page).to have_current_path(%r{\A/chat/c/[^/]+/\d+\z})
    expect(channel_page.messages).to have_message(text: welcome_message)
  end
end
