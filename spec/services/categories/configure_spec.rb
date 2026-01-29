# frozen_string_literal: true

RSpec.describe Categories::Configure do
  fab!(:admin)
  fab!(:category)

  let(:guardian) { Guardian.new(admin) }

  describe ".call" do
    context "with valid params" do
      it "configures the discussion type successfully" do
        result =
          described_class.call(
            guardian:,
            params: {
              category_id: category.id,
              category_type: "discussion",
            },
          )

        expect(result).to be_success
      end
    end

    context "with invalid category_id" do
      it "fails with model not found" do
        result =
          described_class.call(guardian:, params: { category_id: -1, category_type: "discussion" })

        expect(result).to be_failure
        expect(result["result.model.category"].not_found).to be true
      end
    end

    context "with invalid category_type" do
      it "fails with contract error" do
        result =
          described_class.call(
            guardian:,
            params: {
              category_id: category.id,
              category_type: "invalid_type",
            },
          )

        expect(result).to be_failure
        expect(result["result.contract.default"].errors[:category_type]).to be_present
      end
    end

    context "when user cannot modify category" do
      fab!(:user)
      let(:guardian) { Guardian.new(user) }

      it "fails with policy error" do
        result =
          described_class.call(
            guardian:,
            params: {
              category_id: category.id,
              category_type: "discussion",
            },
          )

        expect(result).to be_failure
        expect(result["result.policy.can_modify_category"]).to be_failure
      end
    end

    context "when type is not available" do
      before { allow(Categories::Types::Support).to receive(:available?).and_return(false) }

      it "fails with policy error" do
        result =
          described_class.call(
            guardian:,
            params: {
              category_id: category.id,
              category_type: "support",
            },
          )

        expect(result).to be_failure
        expect(result["result.policy.type_is_available"]).to be_failure
      end
    end
  end
end
