# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::SendChatMessage do
  describe ".configuration_schema" do
    it "uses textarea ui hints for the message body" do
      expect(described_class.configuration_schema.dig(:message, :ui)).to eq(
        control: :textarea,
        rows: 6,
      )
    end
  end
end
