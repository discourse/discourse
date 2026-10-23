# frozen_string_literal: true

RSpec.describe JsonApiKit::Joins do
  subject(:joins) { described_class.for(declarations) }

  fab!(:section) { Fabricate(:category, name: "A section of the forum") }
  fab!(:filed) { Fabricate(:topic, category: section) }
  fab!(:unfiled, :private_message_topic)

  let(:declarations) { [] }
  let(:scope) { Topic.where(id: [filed.id, unfiled.id]) }
  let(:statement) { "LEFT JOIN categories ON categories.id = topics.category_id" }

  describe ".for" do
    context "with a Joins" do
      it "returns the same object" do
        expect(described_class.for(joins)).to be(joins)
      end
    end

    context "with one declaration" do
      let(:declarations) { :category }

      it "joins it" do
        expect(joins.apply(scope).to_sql).to include("LEFT OUTER JOIN")
      end
    end
  end

  describe "#apply" do
    context "with no declarations" do
      it "leaves the scope alone" do
        expect(joins.apply(scope).to_sql).to eq(scope.to_sql)
      end
    end

    context "with an association" do
      let(:declarations) { [:category] }

      it "joins it without dropping rows" do
        expect(joins.apply(scope).map(&:id)).to contain_exactly(filed.id, unfiled.id)
      end
    end

    context "with a SQL statement" do
      let(:declarations) { [statement] }

      it "joins with it" do
        expect(joins.apply(scope).where("categories.name IS NULL").map(&:id)).to eq([unfiled.id])
      end
    end

    context "with both" do
      let(:declarations) { [statement, :category] }

      it "applies both" do
        expect(joins.apply(scope).to_sql).to include("LEFT JOIN categories", "LEFT OUTER JOIN")
      end
    end
  end

  describe "#+" do
    subject(:merged) { joins + described_class.for(:category) }

    let(:declarations) { [statement] }

    it "merges both joins" do
      expect(merged).to eq(described_class.for([statement, :category]))
    end
  end
end
