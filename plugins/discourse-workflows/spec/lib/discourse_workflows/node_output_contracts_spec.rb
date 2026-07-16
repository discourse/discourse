# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType do
  let(:input_schema) do
    {
      "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
      "type" => "object",
      "properties" => {
        "source" => {
          "type" => "string",
        },
      },
    }
  end

  it "preserves declarations through nodes that only forward or reorder items" do
    node_classes = [
      DiscourseWorkflows::Nodes::Log::V1,
      DiscourseWorkflows::Nodes::Sort::V1,
      DiscourseWorkflows::Nodes::RespondToWebhook::V1,
      DiscourseWorkflows::Nodes::LoopOverItems::V1,
    ]

    expect(
      node_classes.map do |node_class|
        node_class.output_schemas({}, input_schemas: [input_schema])
      end,
    ).to eq([[input_schema], [input_schema], [input_schema], [input_schema, input_schema]])
  end

  it "keeps append and preferred combine merge outputs while hiding suffixed keys" do
    node_class = DiscourseWorkflows::Nodes::Merge::V1

    expect(node_class.output_schemas({ "mode" => "append" }, input_schemas: [input_schema])).to eq(
      [input_schema],
    )
    expect(
      node_class.output_schemas(
        { "mode" => "combine", "resolve_clash" => "prefer_first" },
        input_schemas: [input_schema],
      ),
    ).to eq([input_schema])
    expect(
      node_class.output_schemas(
        { "mode" => "combine", "resolve_clash" => "add_suffix" },
        input_schemas: [input_schema],
      ),
    ).to eq([{}])
  end

  it "distinguishes time, webhook, and timeout-capable wait outputs" do
    node_class = DiscourseWorkflows::Nodes::Wait::V1

    expect(
      node_class.output_schemas({ "resume" => "time_interval" }, input_schemas: [input_schema]),
    ).to eq([input_schema])
    expect(
      node_class.output_schemas(
        { "resume" => "webhook", "limit_wait_time" => false },
        input_schemas: [input_schema],
      ),
    ).to eq([DiscourseWorkflows::Schema::WEBHOOK_REQUEST_SCHEMA])
    expect(
      node_class.output_schemas(
        { "resume" => "webhook", "limit_wait_time" => true },
        input_schemas: [input_schema],
      ),
    ).to eq([DiscourseWorkflows::Schema::WEBHOOK_REQUEST_SCHEMA])
    expect(
      node_class.output_schemas(
        { "resume" => "webhook", "limit_wait_time" => true, "timeout_amount" => 1 },
        input_schemas: [input_schema],
      ),
    ).to eq(
      [
        DiscourseWorkflows::Schema.union(
          input_schema,
          DiscourseWorkflows::Schema::WEBHOOK_REQUEST_SCHEMA,
        ),
      ],
    )
  end

  it "accepts every JSON body shape produced by webhook requests" do
    request =
      DiscourseWorkflows::WebhookRequest.new(
        method: "POST",
        path: "events",
        headers: {
          "Content-Type" => "application/json",
        },
        body: ["first", 2, nil],
        query: {
        },
        webhook_url: "https://example.com/workflows/webhook",
      )

    expect(request.item_json).to match_node_output_schema(DiscourseWorkflows::Nodes::Webhook::V1)
  end
end
