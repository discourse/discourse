# frozen_string_literal: true

require_relative "../../evals/lib/console_formatter"

RSpec.describe DiscourseAi::Evals::ConsoleFormatter do
  let(:output) { StringIO.new }

  it "prints a progress bar and a table summarizing results" do
    formatter =
      described_class.new(
        label: "eval-123",
        output: output,
        total_targets: 2,
        persona_key: "default",
      )

    formatter.announce_start

    formatter.record_result(
      display_label: "gpt-4o",
      llm_label: "gpt-4o",
      results: [
        { result: :pass, metadata: { input: "Hello world" }, actual_output: "Bonjour le monde" },
        {
          result: :fail,
          expected_output: "true",
          actual_output: "false",
          metadata: {
            input: "Second case",
          },
        },
      ],
      raw_entries: ["Bonjour le monde", "false"],
      row_prefix: "eval-123",
    )

    formatter.record_result(
      display_label: "gemini",
      llm_label: "gemini",
      results: [
        { result: :fail, metadata: { input: "Hello world" }, actual_output: "Salut" },
        { result: :pass, metadata: { input: "Second case" }, actual_output: "true" },
      ],
      raw_entries: %w[Salut true],
      row_prefix: "eval-123",
    )

    formatter.finalize

    rendered = output.string

    expect(rendered).to include("Starting evaluation eval-123")
    expect(rendered).to include("│ input")
    expect(rendered).to include("│ gpt-4o")
    expect(rendered).to include("│ gemini")
    expect(rendered).to include("[PASS]")
    expect(rendered).to include("[FAIL]")
    expect(rendered).to include("Expected: true")
    expect(rendered).to include("Actual: false")
    expect(rendered).to include("Summary:")
    expect(rendered).to include("Legend:")
  end

  it "renders judged comparison outcomes in the table" do
    formatter =
      described_class.new(
        label: "eval-123",
        output: output,
        total_targets: 2,
        persona_key: "default",
      )

    formatter.record_comparison_judged(
      row_prefix: "eval-123",
      candidates: [
        { label: "default", display_label: "default" },
        { label: "custom", display_label: "custom" },
      ],
      result: {
        winner: "custom",
        winner_explanation: "more accurate",
        ratings: [
          { candidate: "default", rating: 6, explanation: "ok" },
          { candidate: "custom", rating: 9, explanation: "great" },
        ],
      },
    )

    formatter.finalize

    rendered = output.string

    expect(rendered).to include("judge")
    expect(rendered).to include("Winner: custom")
    expect(rendered).to include("Reason: more accurate")
    expect(rendered).to include("default")
    expect(rendered).to include("custom")
    expect(rendered).to include("Winner")
    expect(rendered).to include("9/10 — great")
    expect(rendered).to include("6/10 — ok")
  end

  it "marks ties with ratings and judge reason" do
    formatter =
      described_class.new(
        label: "eval-999",
        output: output,
        total_targets: 2,
        persona_key: "default",
      )

    formatter.record_comparison_judged(
      row_prefix: "eval-999",
      candidates: [
        { label: "candidate1", display_label: "cand1/model" },
        { label: "candidate2", display_label: "cand2/model" },
      ],
      result: {
        winner: :tie,
        winner_explanation: "Both are equivalent",
        ratings: [
          { candidate: "candidate1", rating: 9, explanation: "great" },
          { candidate: "candidate2", rating: 9, explanation: "also great" },
        ],
      },
    )

    formatter.finalize

    rendered = output.string

    expect(rendered).to include("[TIE]")
    expect(rendered).to include("9/10 — great")
    expect(rendered).to include("Tie — Both are equivalent")
    expect(rendered).to include("9/10 — also great")
    expect(rendered).to include("Legend: [PASS]=pass, [FAIL]=fail, [SKIP]=skipped, [TIE]=tie")
  end
end
