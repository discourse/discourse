# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeData do
  describe ".split" do
    it "stores credential references by declared slot" do
      split =
        described_class.split(
          node_type: "action:http_request",
          parameters: {
            "authentication" => "basic_auth",
          },
          credentials: {
            "auth" => {
              "id" => 12,
              "credential_type" => "basic_auth",
            },
          },
        )

      expect(split["parameters"]).to eq("authentication" => "basic_auth")
      expect(split["credentials"]).to eq(
        "auth" => {
          "id" => "12",
          "credential_type" => "basic_auth",
        },
      )
    end

    it "keeps declared parameters unchanged" do
      split =
        described_class.split(
          node_type: "action:http_request",
          parameters: {
            "authentication" => "basic_auth",
            "credential_id" => 12,
          },
        )

      expect(split["parameters"]).to eq("authentication" => "basic_auth", "credential_id" => 12)
      expect(split["credentials"]).to eq({})
    end

    it "removes stored credentials hidden by credential display options" do
      split =
        described_class.split(
          node_type: "action:http_request",
          parameters: {
            "authentication" => "none",
          },
          credentials: {
            "auth" => {
              "id" => 12,
              "credential_type" => "basic_auth",
            },
          },
        )

      expect(split["credentials"]).to eq({})
    end

    it "removes credentials from node types without credential declarations" do
      split =
        described_class.split(
          node_type: "action:log",
          parameters: {
            "message" => "hello",
          },
          credentials: {
            "auth" => {
              "id" => 12,
              "credential_type" => "basic_auth",
            },
          },
        )

      expect(split["credentials"]).to eq({})
    end

    it "does not move direct node settings into parameters" do
      split = described_class.split(node_type: "action:log", parameters: { "message" => "hello" })

      expect(split).not_to have_key("settings")
      expect(split["parameters"]).to eq("message" => "hello")
    end

    it "keeps form trigger parameters separate from webhook IDs" do
      split =
        described_class.split(
          node_type: DiscourseWorkflows::NodeDataShape::FORM_TRIGGER_TYPE,
          parameters: {
            "form_title" => "Signup",
          },
          webhook_id: "form-uuid",
        )

      expect(split["parameters"]).to eq("form_title" => "Signup")
      expect(split[DiscourseWorkflows::WorkflowDocument.node_webhook_id_key]).to eq("form-uuid")
    end
  end

  describe ".direct_settings" do
    it "reads direct node settings directly from the node" do
      node = {
        "notes" => "Shown on canvas",
        "alwaysOutputData" => false,
        "parameters" => {
          "message" => "hello",
        },
      }

      expect(described_class.direct_settings(node)).to eq(
        "notes" => "Shown on canvas",
        "alwaysOutputData" => false,
      )
    end
  end

  describe ".resolved_parameters" do
    it "does not merge credential references into ordinary parameters" do
      node = {
        "parameters" => {
          "authentication" => "basic_auth",
        },
        "credentials" => {
          "auth" => {
            "id" => "12",
            "credential_type" => "basic_auth",
          },
        },
      }

      expect(described_class.resolved_parameters(node)).to eq("authentication" => "basic_auth")
    end
  end
end
