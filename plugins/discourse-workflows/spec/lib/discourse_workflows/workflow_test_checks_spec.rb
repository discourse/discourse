# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTestChecks do
  it "normalizes checks with ids, defaults and string values" do
    normalized =
      described_class.normalize(
        [{ effect: :post_created, conditions: [{ field: "raw", value: 5 }] }],
      )

    expect(normalized.first).to include(
      "effect" => "post_created",
      "mode" => "happens",
      "count" => 1,
    )
    expect(normalized.first["id"]).to be_present
    expect(normalized.first["conditions"].first).to include(
      "field" => "raw",
      "operator" => "equals",
      "value" => "5",
    )
  end

  it "rejects unknown effects, fields, operators, modes and counts" do
    checks =
      described_class.normalize(
        [
          { effect: "chat_message" },
          { effect: "post_created", mode: "sometimes" },
          { effect: "post_created", mode: "count", count: -1 },
          {
            effect: "post_created",
            conditions: [{ field: "tag", operator: "matches", value: "x" }],
          },
        ],
      )

    errors = described_class.errors_for(checks)

    expect(errors).to include(
      "\"chat_message\" is not something a test can check.",
      "\"sometimes\" is not a valid check mode.",
      "A count must be a whole number between 0 and 1000.",
      "\"tag\" is not a field of post_created.",
      "\"matches\" is not a valid comparison.",
    )
  end

  it "accepts the special checks and caps the number of checks" do
    expect(
      described_class.errors_for(
        described_class.normalize([{ effect: "nothing" }, { effect: "finishes" }]),
      ),
    ).to eq([])

    many = described_class.normalize(Array.new(21) { { effect: "finishes" } })
    expect(described_class.errors_for(many)).to eq(["A test can have at most 20 checks."])
  end

  it "builds a check from an effect using its first field" do
    check =
      described_class.from_effect(
        "type" => "personal_message",
        "fields" => {
          "recipient" => "sam",
        },
      )

    expect(check).to include("effect" => "personal_message", "mode" => "happens")
    expect(check["conditions"].first).to include("field" => "recipient", "value" => "sam")
  end
end
