# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ChatConversationsController, if: defined?(Chat) do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:logged_in_users]
    group.add(user)
  end

  def workflow_chat(published:)
    graph =
      build_workflow_graph do |builder|
        builder.node(
          "chat",
          "trigger:workflow_chat",
          configuration: {
            chat_title: "Help desk",
            group_ids: [group.id],
          },
        )
      end
    Fabricate(:discourse_workflows_workflow, published:, **graph)
  end

  def open_conversation(workflow, **params)
    post "/workflows/chat-conversations.json",
         params: {
           workflow_id: workflow.id,
           node_id: "chat",
           **params,
         }
  end

  describe "#create" do
    fab!(:workflow) { workflow_chat(published: true) }

    context "when signed in as a member of an allowed group" do
      before { sign_in(user) }

      it "opens a conversation and returns where to find it" do
        expect { open_conversation(workflow) }.to change {
          DiscourseWorkflows::ChatConversation.count
        }.by(1)

        expect(response.status).to eq(201)
        conversation = DiscourseWorkflows::ChatConversation.last
        expect(conversation).to have_attributes(user:, workflow_id: workflow.id, draft: false)
        expect(conversation.channel.name).to eq("Help desk")
        expect(response.parsed_body).to eq("url" => conversation.channel.relative_url)
      end

      it "returns the same 404 for every trigger the member may not chat with" do
        unpublished = workflow_chat(published: false)

        open_conversation(unpublished)
        expect(response.status).to eq(404)
        open_conversation(workflow, draft: true)
        expect(response.status).to eq(404)
        open_conversation(workflow, node_id: "missing")
        expect(response.status).to eq(404)
        post "/workflows/chat-conversations.json", params: { workflow_id: -1, node_id: "chat" }
        expect(response.status).to eq(404)

        group.remove(user)
        open_conversation(workflow)
        expect(response.status).to eq(404)
        expect(DiscourseWorkflows::ChatConversation.count).to eq(0)
      end

      it "returns a 400 when the trigger is not identified" do
        post "/workflows/chat-conversations.json", params: { workflow_id: workflow.id }

        expect(response.status).to eq(400)
      end

      it "returns a 403 when the member cannot create DMs" do
        SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff]

        open_conversation(workflow)

        expect(response.status).to eq(403)
      end

      it "returns a 404 when workflows are disabled" do
        SiteSetting.enable_discourse_workflows = false

        open_conversation(workflow)

        expect(response.status).to eq(404)
      end

      it "limits how often a member opens conversations" do
        RateLimiter.enable

        11.times { open_conversation(workflow) }

        expect(response.status).to eq(429)
        expect(DiscourseWorkflows::ChatConversation.count).to eq(10)
      end
    end

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "opens a draft conversation on the unpublished workflow" do
        unpublished = workflow_chat(published: false)

        open_conversation(unpublished, draft: true)

        expect(response.status).to eq(201)
        expect(DiscourseWorkflows::ChatConversation.last).to have_attributes(
          user: admin,
          workflow_id: unpublished.id,
          draft: true,
        )
      end
    end

    it "refuses anonymous requests" do
      open_conversation(workflow)

      expect(response.status).to eq(403)
      expect(DiscourseWorkflows::ChatConversation.count).to eq(0)
    end

    context "with forgery protection" do
      before do
        ActionController::Base.allow_forgery_protection = true
        sign_in(user)
      end

      after { ActionController::Base.allow_forgery_protection = false }

      it "refuses a request without a CSRF token" do
        open_conversation(workflow)

        expect(response.status).to eq(403)
        expect(DiscourseWorkflows::ChatConversation.count).to eq(0)
      end
    end
  end

  describe "launch URL" do
    fab!(:workflow) { workflow_chat(published: true) }

    before { sign_in(user) }

    it "renders the app without opening a conversation" do
      expect { get "/workflows/chat/#{workflow.id}/chat" }.to not_change {
        DiscourseWorkflows::ChatConversation.count
      }.and not_change { Chat::Channel.count }

      expect(response.status).to eq(200)
    end
  end

  describe "route ownership" do
    it "leaves the chat plugin without any workflow chat route" do
      chat_routes = Chat::Engine.routes.routes.map { |route| route.path.spec.to_s }.grep(/workflow/)

      expect(chat_routes).to be_empty
    end
  end
end
