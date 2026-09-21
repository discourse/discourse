# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePacks::DeclarativeNode do
  fab!(:admin)
  fab!(:credential) do
    Fabricate(
      :discourse_workflows_credential,
      credential_type: "bearer_token",
      data: {
        "token" => "very-secret-token",
      },
    )
  end

  let(:manifest) do
    File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
  end
  let(:node_class) do
    DiscourseWorkflows::Registry.find_node_type("action:jev.choice", version: "1.0")
  end
  let(:parameters) do
    {
      "model" => "jev-latest",
      "state" => "support body",
      "question" => "Where?",
      "options" => {
        "values" => [
          { "key" => "billing", "description" => "Payments" },
          { "key" => "other", "description" => "" },
        ],
      },
    }
  end
  let(:credentials) { { "auth" => { "id" => credential.id, "credential_type" => "bearer_token" } } }

  before do
    DiscourseWorkflows::NodePack::Install.call(
      params: {
        manifest:,
        approved_destinations: ["https://api.typesafe.ai"],
      },
      guardian: admin.guardian,
    )
  end

  after { DiscourseWorkflows::NodePacks::Runtime.clear! }

  it "sends the declared request with credentials and returns typed paired output" do
    expected_body = {
      "state" => "support body",
      "model" => "jev-latest",
      "questions" => {
        "answer" => {
          "type" => "choice",
          "instructions" => "Where?",
          "criteria" => {
            "billing" => "Payments",
          },
        },
      },
    }
    request =
      stub_request(:post, "https://api.typesafe.ai/v1/systemone")
        .with(headers: { "Authorization" => "Bearer very-secret-token" })
        .with { |http_request| JSON.parse(http_request.body) == expected_body }
        .to_return(
          status: 200,
          headers: {
            "content-type" => "application/json",
          },
          body: {
            answers: {
              answer: {
                choice: "billing",
                probabilities: {
                  billing: 0.9,
                },
                confidence: 0.8,
              },
            },
            model: "jev-latest",
            usage: {
            },
          }.to_json,
        )

    output = execute(parameters:, credentials:)

    expect(request).to have_been_requested.once
    expect(output.first.first).to include(
      "json" => include("choice" => "billing", "confidence" => 0.8),
      "pairedItem" => {
        "item" => 0,
      },
    )
  end

  it "does not follow redirects or expose redirected response bodies" do
    redirect =
      stub_request(:post, "https://api.typesafe.ai/v1/systemone").to_return(
        status: 302,
        headers: {
          "location" => "https://unapproved.example/steal",
        },
        body: "response-secret",
      )
    unapproved = stub_request(:get, "https://unapproved.example/steal")

    expect { execute(parameters:, credentials:) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /status 302/,
    ) do |error|
      expect(error.message).not_to include("response-secret")
    end
    expect(redirect).to have_been_requested.once
    expect(unapproved).not_to have_been_requested
  end

  it "fails before making a request when the credential is missing" do
    expect { execute(parameters:, credentials: {}) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /Select a credential/,
    )
    expect(a_request(:post, "https://api.typesafe.ai/v1/systemone")).not_to have_been_made
  end

  it "blocks userinfo in a stored request URL before dispatch" do
    definition = DiscourseWorkflows::NodePackDefinition.find_by!(identifier: "action:jev.choice")
    tampered = definition.definition.deep_dup
    tampered["request"]["url"] = "https://user:password@api.typesafe.ai/v1/systemone"
    definition.update_column(:definition, tampered)
    DiscourseWorkflows::NodePacks::Runtime.bump!
    tampered_node_class =
      DiscourseWorkflows::Registry.find_node_type("action:jev.choice", version: "1.0")

    expect do
      execute(parameters:, credentials:, node_class: tampered_node_class)
    end.to raise_error(DiscourseWorkflows::NodeError, /not approved/)
    expect(a_request(:post, /api\.typesafe\.ai/)).not_to have_been_made
  end

  it "blocks dangerous headers supplied by header authentication" do
    value = JSON.parse(manifest)
    value["key"] = "headers"
    value["version"] = "1.0.0"
    value["credentials"][0]["credential_types"] = ["header_auth"]
    value["nodes"] = [value["nodes"].first]
    installed =
      DiscourseWorkflows::NodePack::Install.call(
        params: {
          manifest: value,
          approved_destinations: ["https://api.typesafe.ai"],
        },
        guardian: admin.guardian,
      )
    expect(installed).to run_successfully
    header_credential =
      Fabricate(
        :discourse_workflows_credential,
        credential_type: "header_auth",
        data: {
          "name" => "Host",
          "value" => "unapproved.example",
        },
      )
    header_node_class =
      DiscourseWorkflows::Registry.find_node_type("action:headers.choice", version: "1.0")
    header_credentials = {
      "auth" => {
        "id" => header_credential.id,
        "credential_type" => "header_auth",
      },
    }

    expect do
      execute(parameters:, credentials: header_credentials, node_class: header_node_class)
    end.to raise_error(DiscourseWorkflows::NodeError, /header is not allowed/)
    expect(a_request(:post, "https://api.typesafe.ai/v1/systemone")).not_to have_been_made
  end

  it "wraps scalar outputs only when no output schema is declared" do
    value = JSON.parse(manifest)
    value["key"] = "scalar"
    value["nodes"] = [value["nodes"].first]
    value["nodes"][0]["response"] = { "output" => { "$response" => "answers.answer.choice" } }
    installed =
      DiscourseWorkflows::NodePack::Install.call(
        params: {
          manifest: value,
          approved_destinations: ["https://api.typesafe.ai"],
        },
        guardian: admin.guardian,
      )
    expect(installed).to run_successfully
    scalar_node_class =
      DiscourseWorkflows::Registry.find_node_type("action:scalar.choice", version: "1.0")
    stub_request(:post, "https://api.typesafe.ai/v1/systemone").to_return(
      status: 200,
      headers: {
        "content-type" => "application/json",
      },
      body: { answers: { answer: { choice: "billing" } } }.to_json,
    )

    output = execute(parameters:, credentials:, node_class: scalar_node_class)

    expect(output.first.first["json"]).to eq("data" => "billing")
  end

  it "rejects a response that does not match the pinned output schema without leaking it" do
    secret_response = { answers: { answer: { choice: 42 } }, secret: "response-secret" }
    stub_request(:post, "https://api.typesafe.ai/v1/systemone").to_return(
      status: 200,
      headers: {
        "content-type" => "application/json",
      },
      body: secret_response.to_json,
    )

    expect { execute(parameters:, credentials:) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /did not match/,
    ) do |error|
      expect(error.message).not_to include(secret_response[:secret])
    end
  end

  private

  def execute(parameters:, credentials:, node_class: nil)
    node_class ||= self.node_class
    input_items = [{ "json" => {} }]
    resolver_context = { "$json" => {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context, user: admin)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox:, user: admin)
    context =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items:,
        parameters:,
        credentials:,
        property_schema: node_class.property_schema,
        credential_schema: node_class.credentials,
        node_identifier: node_class.identifier,
        resolver_context:,
        resolver:,
        user: admin,
      )
    node_class.new(parameters:, credentials:).execute(context)
  ensure
    resolver&.dispose
    sandbox&.dispose
  end
end
