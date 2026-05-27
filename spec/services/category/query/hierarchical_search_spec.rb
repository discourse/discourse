# frozen_string_literal: true

RSpec.describe Category::Query::HierarchicalSearch do
  # before_all: allows fab! to create 3-level nested categories
  # before: ensures setting persists (site settings reset between tests)
  before_all { SiteSetting.max_category_nesting = 3 }
  before { SiteSetting.max_category_nesting = 3 }

  fab!(:user)
  fab!(:parent) { Fabricate(:category, name: "Parent") }
  fab!(:child) { Fabricate(:category, name: "Child", parent_category: parent) }
  fab!(:grandchild) { Fabricate(:category, name: "Grandchild Match", parent_category: child) }

  let(:guardian) { Guardian.new(user) }
  let(:term) { "" }
  let(:only) { [] }
  let(:except) { [] }
  let(:page) { 1 }
  let(:params) { Category::HierarchicalSearch::Contract.new(term:, only:, except:, page:) }

  describe "#call" do
    subject(:result) { described_class.new(guardian:, params:).call }

    context "when searching by term" do
      let(:term) { "match" }

      it "returns matching categories with ancestors in hierarchical order" do
        expect(result).to eq([parent, child, grandchild])
      end
    end

    context "when filtering by only" do
      let(:only) { [grandchild.id] }

      it "returns specified categories with ancestors" do
        expect(result).to eq([parent, child, grandchild])
      end
    end

    context "when filtering by except" do
      let(:except) { [grandchild.id] }

      it "excludes specified categories" do
        expect(result).to eq([parent, child])
      end
    end

    context "when paginating" do
      let(:page) { 2 }

      it "offsets results by page" do
        # Page 2 with limit 25 would offset by 25, returning nothing for our small dataset
        expect(result).to be_empty
      end
    end

    context "when guardian cannot see category" do
      fab!(:restricted_group, :group)
      fab!(:restricted_category) do
        Fabricate(:category, name: "Restricted").tap do |c|
          c.set_permissions(restricted_group => :full)
          c.save!
        end
      end

      let(:term) { "restricted" }

      it "excludes restricted categories" do
        expect(result).to be_empty
      end
    end

    it "excludes uncategorized category" do
      expect(result).not_to include(have_attributes(id: SiteSetting.uncategorized_category_id))
    end
  end
end
