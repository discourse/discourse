# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::RequestFailed do
  describe ".redact" do
    it "redacts short header tokens without changing words containing configuration flags" do
      expect(
        described_class.redact(
          "untrue falsehood: true false; rejected 'abc' and 7",
          nil,
          header_values: %w[true false abc 7],
        ),
      ).to eq("untrue falsehood: [redacted] [redacted]; rejected '[redacted]' and [redacted]")
    end

    it "preserves short header values within identifiers and versions while scrubbing standalone echoes" do
      expect(
        described_class.redact(
          "version0.1 jev-1.13.0 prefix-xy-suffix: '1' and 'xy'",
          nil,
          header_values: %w[1 xy],
        ),
      ).to eq("version0.1 jev-1.13.0 prefix-xy-suffix: '[redacted]' and '[redacted]'")
    end

    it "redacts short credentials next to sentence punctuation" do
      expect(
        described_class.redact(
          "Invalid token ab12. Also rejected (ab12), ab12! and ab12...",
          nil,
          header_values: ["ab12"],
        ),
      ).to eq("Invalid token [redacted]. Also rejected ([redacted]), [redacted]! and [redacted]...")
    end

    it "redacts API keys as substrings even when they are short or match configuration flags" do
      expect(described_class.redact("untrue true", "true", header_values: ["true"])).to eq(
        "un[redacted] [redacted]",
      )
      expect(described_class.redact("prefix-xs-suffix", "xs")).to eq("prefix-[redacted]-suffix")
    end

    it "replaces overlapping values once without redacting the replacement" do
      expect(
        described_class.redact(
          "private-token token redacted acted Bearer private-token key-example",
          nil,
          header_values: %w[token private-token redacted acted],
        ),
      ).to eq("[redacted] [redacted] [redacted] [redacted] Bearer [redacted] [redacted]")
    end
  end

  describe ".redact_response" do
    it "preserves JSON booleans, numbers and field names while redacting string echoes" do
      body = {
        success: true,
        errors: false,
        result: {
          probabilities: {
            "0" => 0.1,
            "1" => 0.9,
          },
          count: 1,
        },
        echoes: ["true", "false", "1", "xy", nil],
      }

      redacted =
        described_class.redact_response(body.to_json, nil, header_values: %w[true false 1 xy])

      expect(JSON.parse(redacted)).to eq(
        "success" => true,
        "errors" => false,
        "result" => {
          "probabilities" => {
            "0" => 0.1,
            "1" => 0.9,
          },
          "count" => 1,
        },
        "echoes" => ["[redacted]", "[redacted]", "[redacted]", "[redacted]", nil],
      )
    end

    it "preserves scalar JSON responses" do
      [true, false, 1, 0.1, nil].each do |scalar|
        expect(
          JSON.parse(
            described_class.redact_response(scalar.to_json, "1", header_values: %w[true false]),
          ),
        ).to eq(scalar)
      end
    end

    it "redacts escaped credentials after decoding JSON and keeps the stored JSON valid" do
      header_value = 'a"b\\c'
      body = { message: "Rejected #{header_value}", nested: [header_value] }.to_json

      expect(
        JSON.parse(described_class.redact_response(body, nil, header_values: [header_value])),
      ).to eq("message" => "Rejected [redacted]", "nested" => ["[redacted]"])
      expect(JSON.parse(described_class.redact_response('"\\u0061\\u0062"', "ab"))).to eq(
        "[redacted]",
      )
    end

    it "scrubs API keys in JSON field names" do
      expect(JSON.parse(described_class.redact_response('{"xs": "value"}', "xs"))).to eq(
        "[redacted]" => "value",
      )
    end

    it "scrubs non-JSON diagnostics including JSON-escaped header values" do
      header_value = 'a"b\\c'
      text = "untrue: rejected #{header_value.to_json} and xy"

      expect(
        described_class.redact_response(text, nil, header_values: ["true", header_value, "xy"]),
      ).to eq('untrue: rejected "[redacted]" and [redacted]')
    end
  end
end
