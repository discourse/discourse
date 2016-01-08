require 'rails_helper'

describe TrustLevel do
  describe 'levels' do
    context "verify enum sequence" do
      before do
        @levels = TrustLevel.levels
      end

      it "'newuser' should be at 0 position" do
        expect(@levels[:newuser]).to eq(0)
      end

      it "'leader' should be at 4th position" do
        expect(@levels[:leader]).to eq(4)
      end
    end
  end
end
