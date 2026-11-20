# frozen_string_literal: true

RSpec.describe Jobs::RemindUser do
  describe "#execute" do
    it "raises InvalidParameters when user_id is missing" do
      expect do described_class.new.execute({}) end.to raise_error(Discourse::InvalidParameters)
    end
  end
end
