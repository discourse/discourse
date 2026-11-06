# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::Tool do
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

  describe "#compact_approval_details" do
    fab!(:admin)

    let(:notice) { I18n.t("discourse_ai.ai_bot.chat_tool_approval.details_shortened") }
    let(:tool) do
      Class
        .new(described_class) do
          def self.name
            "long_details"
          end

          def approval_details
            "#{"a" * 200}\n\n#{"b" * 200}"
          end
        end
        .new(
          {},
          bot_user: admin,
          llm: nil,
          context: DiscourseAi::Agents::BotContext.new(user: admin, messages: []),
        )
    end

    it "keeps the start of the details after a notice and fits the limit" do
      details = tool.compact_approval_details(max_length: 120)

      expect(details.length).to be <= 120
      expect(details).to start_with("#{notice}\n\naaa")
      expect(details).not_to include("b")
    end

    it "returns only the notice when there is no room for the details" do
      expect(tool.compact_approval_details(max_length: 20)).to eq(notice.truncate(20))
    end
  end
end
