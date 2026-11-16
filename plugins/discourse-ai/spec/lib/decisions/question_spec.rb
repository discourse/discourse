# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::Question do
  describe ".wrap" do
    it "builds typed questions with stripped strings and preserves wrapped questions" do
      question =
        described_class.wrap(
          "name" => " team ",
          "type" => "choice",
          "instructions" => " Who? ",
          "choices" => [" billing ", "returns"],
        )
      expect(question).to have_attributes(
        name: "team",
        type: :choice,
        instructions: "Who?",
        choices: %w[billing returns],
        levels: nil,
      )
      expect(described_class.wrap(question)).to equal(question)
      expect(
        described_class.new(
          name: "severity",
          type: :score,
          instructions: "How bad?",
          levels: [" low ", "high"],
        ).levels,
      ).to eq(%w[low high])
    end

    it "identifies the question and invalid field" do
      base = { name: "team", type: "choice", instructions: "Who?", choices: %w[billing returns] }
      [
        [:name, "1team"],
        [:name, "a" * 65],
        [:type, "unknown"],
        [:instructions, " "],
        [:levels, %w[low high]],
        [:choices, ["only"]],
        [:choices, Array.new(256) { |index| index.to_s }],
        [:choices, ["same", " same "]],
        [:choices, ["", "valid"]],
        [:choices, [1, "valid"]],
        [:choices, { "a" => "a", "b" => "b" }],
      ].each do |field, value|
        expect { described_class.wrap(base.merge(field => value)) }.to raise_error(
          DiscourseAi::Decisions::InvalidRequest,
          /Question .*#{field}:/,
        )
      end
      [nil, ["only"], Array.new(11) { |index| index.to_s }, %w[a a], ["a", " "]].each do |levels|
        expect {
          described_class.new(name: "severity", type: :score, instructions: "How bad?", levels:)
        }.to raise_error(DiscourseAi::Decisions::InvalidRequest, /severity.*levels/)
      end
      expect { described_class.wrap({}) }.to raise_error(
        DiscourseAi::Decisions::InvalidRequest,
        /name:/,
      )
      expect { described_class.wrap(base.merge(type: "yes_no")) }.to raise_error(
        DiscourseAi::Decisions::InvalidRequest,
        /choices:/,
      )
    end

    it "accepts the name and collection limits" do
      expect(
        described_class
          .new(
            name: "_" + "a" * 63,
            type: :choice,
            instructions: "Who?",
            choices: Array.new(255) { |index| index.to_s },
          )
          .choices
          .size,
      ).to eq(255)
      expect(
        described_class
          .new(
            name: "severity",
            type: :score,
            instructions: "How bad?",
            levels: Array.new(10) { |index| index.to_s },
          )
          .levels
          .size,
      ).to eq(10)
    end
  end
end
