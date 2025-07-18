# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::RemindUser do
  describe "#execute" do
    it "should raise the right error when user_id is invalid" do
      expect do described_class.new.execute({}) end.to raise_error(Discourse::InvalidParameters)
    end
  end
end
