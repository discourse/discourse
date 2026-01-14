# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Tool do
  let :tool_class do
    described_class
  end

  let :corrupt_string do
    "\xC3\x28\xA0\xA1\xE2\x28\xA1\xE2\x82\x28\xF0\x28\x8C\xBC"
  end

  before { enable_current_plugin }

  describe "#read_response_body" do
    class FakeResponse
      def initialize(chunk)
        @chunk = chunk
      end

      def read_body
        yield @chunk while true
      end
    end

    it "never returns a corrupt string" do
      response = FakeResponse.new(corrupt_string)
      result = tool_class.read_response_body(response, max_length: 100.bytes)

      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to eq(true)

      # scrubbing removes 7 chars
      expect(result.length).to eq(93)
    end

    it "returns correctly truncated strings" do
      response = FakeResponse.new("abc")
      result = tool_class.read_response_body(response, max_length: 10.bytes)

      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to eq(true)

      expect(result).to eq("abcabcabca")
    end
  end
end
