# frozen_string_literal: true

RSpec.describe PostActionType do
  describe "#types" do
    context "when verifying enum sequence" do
      before { @types = PostActionType.types }

      it "'spam' should be at 8th position" do
        expect(@types[:spam]).to eq(8)
      end
    end
  end
end
