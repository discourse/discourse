# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Direction do
  subject(:direction) { described_class.for(declared) }

  let(:declared) { :asc }

  describe ".for" do
    context "with a direction nothing sorts in" do
      let(:declared) { :sideways }

      it "refuses it where the key is declared" do
        expect { direction }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#to_sym" do
    it "is the direction as it was declared" do
      expect(direction.to_sym).to eq(:asc)
    end
  end

  describe "#to_sql" do
    subject(:to_sql) { direction.to_sql }

    it "names the way the database sorts" do
      expect(to_sql).to eq("ASC")
    end

    context "when it sorts descending" do
      let(:declared) { :desc }

      it "names that way instead" do
        expect(to_sql).to eq("DESC")
      end
    end
  end

  describe "#operator" do
    subject(:operator) { direction.operator }

    it "compares a row as following the cursor when its value is greater" do
      expect(operator).to eq(">")
    end

    context "when it sorts descending" do
      let(:declared) { :desc }

      it "follows when the value is smaller" do
        expect(operator).to eq("<")
      end
    end
  end

  describe "#reversed" do
    subject(:reversed) { direction.reversed }

    it "declares the way back" do
      expect(reversed).to eq(:desc)
    end

    context "when it sorts descending" do
      let(:declared) { :desc }

      it "declares the way out" do
        expect(reversed).to eq(:asc)
      end
    end
  end

  describe "#nulls_first?" do
    it "reads nulls where the database puts them ascending, which is last" do
      expect(direction).not_to be_nulls_first
    end

    context "when it sorts descending" do
      let(:declared) { :desc }

      it "reads them where the database puts them descending, which is first" do
        expect(direction).to be_nulls_first
      end
    end
  end

  describe "#==" do
    it "is the same value however often it is read" do
      expect(direction).to eq(described_class.for(:asc))
    end

    it "differs from the direction it reverses into" do
      expect(direction).not_to eq(described_class.for(:desc))
    end

    it "counts once among the directions an order sorts by" do
      expect([described_class.for(:asc), described_class.for(:asc)].uniq).to contain_exactly(
        direction,
      )
    end
  end
end
