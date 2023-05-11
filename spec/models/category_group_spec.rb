# frozen_string_literal: true

RSpec.describe CategoryGroup do
  describe "#permission_types" do
    context "when verifying enum sequence" do
      before { @permission_types = CategoryGroup.permission_types }

      it "'full' should be at 1st position" do
        expect(@permission_types[:full]).to eq(1)
      end

      it "'readonly' should be at 3rd position" do
        expect(@permission_types[:readonly]).to eq(3)
      end
    end
  end
end
