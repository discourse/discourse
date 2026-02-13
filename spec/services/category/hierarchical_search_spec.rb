# frozen_string_literal: true

RSpec.describe Category::HierarchicalSearch do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(page:) }

    let(:page) { 1 }

    it { is_expected.to allow_values(1, 100).for(:page) }
    it { is_expected.not_to allow_values(0, -1).for(:page) }

    describe "#limit" do
      it { expect(contract.limit).to eq(CategoriesController::MAX_CATEGORIES_LIMIT) }
    end

    describe "#offset" do
      let(:page) { 3 }

      it { expect(contract.offset).to eq(2 * CategoriesController::MAX_CATEGORIES_LIMIT) }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(guardian:, params:) }

    fab!(:user)
    fab!(:category)

    let(:guardian) { Guardian.new(user) }
    let(:params) { { term: "test" } }
    let(:categories) { [category] }
    let(:query_instance) { instance_double(Category::Query::HierarchicalSearch, call: categories) }

    context "with invalid data" do
      let(:params) { { page: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      before do
        allow(Category::Query::HierarchicalSearch).to receive(:new).and_return(query_instance)
        allow(Category::Action::EagerLoadAssociations).to receive(:call)
      end

      it { is_expected.to run_successfully }

      it "returns categories from hierarchical search" do
        expect(result.categories).to eq(categories)
        expect(Category::Query::HierarchicalSearch).to have_received(:new).with(
          guardian:,
          params: result[:params],
        )
      end

      it "eager loads associations" do
        result
        expect(Category::Action::EagerLoadAssociations).to have_received(:call).with(
          categories:,
          guardian:,
        )
      end
    end
  end
end
