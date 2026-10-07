# frozen_string_literal: true

RSpec.describe JsonApiKit::Schema do
  subject(:schema) { described_class.new(Topic) }

  fab!(:topic) { Fabricate(:topic, title: "A row the kit asks about") }

  describe "#primary_key" do
    it "returns the column that identifies a row" do
      expect(schema.primary_key).to eq(:id)
    end
  end

  describe "#column" do
    it "returns the column the model holds under that name" do
      expect(schema.column("title")).to eq(:title)
    end

    context "when a caller spells the name as a symbol" do
      it "returns the same column" do
        expect(schema.column(:title)).to eq(:title)
      end
    end

    context "when the model holds no column under that name" do
      it "returns nothing" do
        expect(schema.column("worked_out_somehow")).to be_nil
      end
    end
  end

  describe "#nullable?" do
    context "when the column forbids null" do
      it { is_expected.not_to be_nullable("title") }
    end

    context "when the column allows null" do
      it { is_expected.to be_nullable("category_id") }
    end

    context "when the model holds no column under that name" do
      it "returns true, having nothing to promise otherwise" do
        expect(schema).to be_nullable("worked_out_somehow")
      end
    end
  end

  describe "#association" do
    it "returns an association between the two tables" do
      expect(schema.association(:user, [topic])).to be_an_instance_of(JsonApiKit::Association)
    end

    context "when the relationship goes through another table" do
      it "returns an association that reads the table between them" do
        expect(schema.association(:tags, [topic])).to be_a(JsonApiKit::Association::Through)
      end
    end
  end

  describe "#table_of" do
    subject(:table) { schema.table_of(:user) }

    it { is_expected.to eq("users") }

    context "when the association doesn’t exist" do
      subject(:table) { schema.table_of(:author) }

      it { expect { table }.to raise_error(described_class::MissingAssociation, /author/) }
    end
  end
end
