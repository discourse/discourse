require 'rails_helper'

describe PostActionType do

  describe '#types' do
    context "verify enum sequence" do
      before do
        @types = PostActionType.types
      end

      it "'bookmark' should be at 1st position" do
        expect(@types[:bookmark]).to eq(1)
      end

      it "'spam' should be at 8th position" do
        expect(@types[:spam]).to eq(8)
      end
    end
  end
end
