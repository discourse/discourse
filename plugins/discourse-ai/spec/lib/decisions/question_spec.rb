# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::Question do
  describe ".from_h" do
    it "normalizes shorthand choices and plain levels into the canonical shape" do
      choice =
        described_class.from_h(
          "type" => "choice",
          "name" => "team",
          "instructions" => "Who handles it?",
          "choices" => {
            "billing" => "Payments",
            "returns" => nil,
          },
        )
      score =
        described_class.from_h(
          type: :score,
          name: "severity",
          instructions: "How bad?",
          levels: ["low", { description: "Blocks work" }],
        )

      expect(choice.to_h).to eq(
        type: "choice",
        name: "team",
        instructions: "Who handles it?",
        choices: [{ value: "billing", description: "Payments" }, { value: "returns" }],
      )
      expect(score.levels).to eq(
        [{ label: "low" }, { label: "Blocks work", description: "Blocks work" }],
      )
    end

    it "round-trips through #to_h and JSON" do
      question =
        described_class.score(
          "severity",
          "How bad?",
          [{ label: "low", description: "Minor" }, { label: "high" }],
        )

      expect(described_class.from_h(JSON.parse(question.to_json)).to_h).to eq(question.to_h)
    end

    it "raises InvalidQuestion pointing at the broken field" do
      expect {
        described_class.from_h(
          type: "choice",
          name: "team",
          instructions: "Who?",
          choices: [{ value: "billing" }, { value: "billing" }],
        )
      }.to raise_error(
        an_instance_of(DiscourseAi::Decisions::InvalidQuestion).and(
          having_attributes(name: "team", field: :choices, message: /must be unique/),
        ),
      )
      expect {
        described_class.from_h(type: "yes_no", name: "is-spam", instructions: "Spam?")
      }.to raise_error(DiscourseAi::Decisions::InvalidQuestion) { |error|
        expect(error.field).to eq(:name)
      }
      expect {
        described_class.from_h(type: nil, name: "spam", instructions: "Spam?")
      }.to raise_error(DiscourseAi::Decisions::InvalidQuestion) { |error|
        expect(error.field).to eq(:type)
      }
    end
  end
end
