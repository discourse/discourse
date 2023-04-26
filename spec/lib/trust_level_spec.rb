# frozen_string_literal: true

RSpec.describe TrustLevel do
  describe "levels" do
    context "when verifying enum sequence" do
      before { @levels = TrustLevel.levels }

      it "'newuser' should be at 0 position" do
        expect(@levels[:newuser]).to eq(0)
      end

      it "'leader' should be at 4th position" do
        expect(@levels[:leader]).to eq(4)
      end
    end
  end
end
