# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookTestListener do
  fab!(:admin)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "webhook-1",
               "trigger:webhook",
               configuration: {
                 "path" => "test-hook",
                 "http_method" => "POST",
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
  end

  let(:trigger_node) { workflow.find_node("webhook-1") }

  describe ".create!" do
    it "stores a short-lived listener with a draft workflow snapshot" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      expect(described_class.find(listener.listener_id)).to have_attributes(
        listener_id: listener.listener_id,
        workflow_id: workflow.id,
        user_id: admin.id,
        trigger_node_id: "webhook-1",
        http_method: "POST",
        path: "test-hook",
      )
      expect(listener.test_url).to eq("/workflows/webhook-test/#{listener.listener_id}/test-hook")
      expect(listener.expires_at).to be_between(
        Time.current,
        Time.current + described_class::TTL,
      ).inclusive
    end
  end

  describe ".purge_expired!" do
    it "deletes only listeners past their expires_at" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      DiscourseWorkflows::Webhook.where(webhook_id: listener.listener_id).update_all(
        expires_at: 1.minute.ago,
      )

      expect { described_class.purge_expired! }.to change {
        DiscourseWorkflows::Webhook.test_listeners.count
      }.by(-1)
    end
  end

  describe ".find_for_request" do
    it "returns the listener only when the id and route match" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      expect(
        described_class.find_for_request(
          listener_id: listener.listener_id,
          method: "POST",
          path: "test-hook",
        ),
      ).to have_attributes(listener_id: listener.listener_id)
      expect(
        described_class.find_for_request(
          listener_id: listener.listener_id,
          method: "GET",
          path: "test-hook",
        ),
      ).to be_nil
      expect(
        described_class.find_for_request(
          listener_id: SecureRandom.uuid,
          method: "POST",
          path: "test-hook",
        ),
      ).to be_nil
    end
  end

  describe ".claim" do
    it "returns and consumes the matching listener once" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      claimed =
        described_class.claim(described_class.find_by_route(method: "POST", path: "test-hook"))

      expect(claimed.listener_id).to eq(listener.listener_id)
      expect(described_class.find_by_route(method: "POST", path: "test-hook")).to be_nil
      expect(described_class.find(listener.listener_id)).to be_nil
    end

    it "does not consume the listener when the HTTP method does not match" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      expect(described_class.find_by_route(method: "GET", path: "test-hook")).to be_nil
      expect(described_class.find_by_route(method: "POST", path: "test-hook").listener_id).to eq(
        listener.listener_id,
      )
    end

    it "does not replace another active listener on the same route" do
      other_admin = Fabricate(:admin)
      described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      expect do
        described_class.create!(workflow: workflow, user: other_admin, trigger_node: trigger_node)
      end.to raise_error(described_class::ActiveRouteExists)
    end

    it "replaces the same user's active listener for the same node" do
      first = described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      second = described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      expect(described_class.find(first.listener_id)).to be_nil
      expect(described_class.find_by_route(method: "POST", path: "test-hook").listener_id).to eq(
        second.listener_id,
      )
    end
  end

  describe ".cancel!" do
    it "removes the listener and route lookup" do
      listener =
        described_class.create!(workflow: workflow, user: admin, trigger_node: trigger_node)

      described_class.cancel!(listener)

      expect(described_class.find(listener.listener_id)).to be_nil
      expect(described_class.find_by_route(method: "POST", path: "test-hook")).to be_nil
    end
  end
end
