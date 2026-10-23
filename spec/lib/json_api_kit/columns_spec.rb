# frozen_string_literal: true

RSpec.describe JsonApiKit::Columns do
  subject(:columns) { described_class.for(%i[id title]) }

  fab!(:topic) { Fabricate(:topic, title: "A row read column by column") }

  let(:scope) { Topic.all }

  describe ".for" do
    context "when one of them is not known" do
      subject(:columns) { described_class.for([:title, nil]) }

      it "returns every column" do
        expect(columns).to eq(described_class.all)
      end
    end
  end

  describe "#apply" do
    subject(:rows) { columns.apply(scope) }

    it "reads only those columns" do
      expect(rows.first.attributes.keys).to contain_exactly("id", "title")
    end

    context "when it is every column" do
      subject(:columns) { described_class.all }

      it "reads the whole row" do
        expect(rows.first.attributes.keys).to include("id", "title", "closed", "views")
      end
    end
  end

  describe "#with" do
    subject(:rows) { columns.with(:created_at, :id).apply(scope) }

    it "reads those columns too, each one once" do
      expect(rows.first.attributes.keys).to contain_exactly("id", "title", "created_at")
    end

    context "when it is every column" do
      subject(:columns) { described_class.all }

      it "returns every column" do
        expect(columns.with(:created_at)).to eq(columns)
      end
    end
  end

  describe "#==" do
    it "equals the same columns" do
      expect(columns).to eq(described_class.for(%i[id title]))
    end

    it "differs from other columns" do
      expect(columns).not_to eq(described_class.for(%i[id]))
    end

    it "differs from every column" do
      expect(columns).not_to eq(described_class.all)
    end
  end
end
