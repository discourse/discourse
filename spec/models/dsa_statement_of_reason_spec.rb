# frozen_string_literal: true
RSpec.describe DsaStatementOfReason do
  describe "#reverse!" do
    it "retains the attempted payload when restoration uses a stale record" do
      statement = Fabricate(:dsa_statement_of_reason)
      original_payload = statement.payload
      described_class.find(statement.id).begin_attempt!

      statement.reverse!

      expect(statement.reload.attempts).to eq(1)
      expect(statement.reversed_at).to be_present
      expect(statement.payload).to eq(original_payload)
    end
  end
end
