# frozen_string_literal: true

RSpec.describe Categories::Unconfigure do
  describe Categories::Unconfigure::Contract, type: :model do
    it { is_expected.to validate_presence_of(:category_id) }
    it { is_expected.to validate_presence_of(:category_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:category)

    let(:params) { { category_id: category.id, category_type: "discussion" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when params are invalid" do
      let(:params) { { category_id: nil, category_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when category type is invalid" do
      let(:params) { super().merge(category_type: "invalid_type") }

      it { is_expected.to fail_a_contract }
    end

    context "when category is not found" do
      let(:params) { super().merge(category_id: -1) }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when user cannot modify category" do
      fab!(:user)
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_modify_category) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "calls unconfigure_category on the type class" do
        Categories::Types::Discussion.expects(:unconfigure_category).once
        result
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:custom_staff],
          custom_type: "unconfigure_category_type",
          acting_user_id: admin.id,
        )
        expect(UserHistory.last.details).to include("category_type")
      end

      it "clears the category type counts cache" do
        Discourse.cache.write(Categories::TypeRegistry::COUNTS_CACHE_KEY, "cached_value")
        result
        expect(Discourse.cache.read(Categories::TypeRegistry::COUNTS_CACHE_KEY)).to be_nil
      end
    end
  end
end
