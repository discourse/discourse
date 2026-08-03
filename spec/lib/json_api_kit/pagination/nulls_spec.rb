# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Nulls do
  subject(:nulls) { described_class.for(placement, direction:) }

  let(:placement) { :last }
  let(:direction) { JsonApiKit::Pagination::Direction.for(:asc) }

  describe ".for" do
    context "when nulls cannot sort at that placement" do
      let(:placement) { :middle }

      it "refuses the placement" do
        expect { nulls }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#expected?" do
    context "when the placement is last" do
      it { is_expected.to be_expected }
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      it { is_expected.not_to be_expected }
    end
  end

  describe "#placement" do
    context "when the placement is last" do
      it "returns last" do
        expect(nulls.placement).to eq(:last)
      end
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      it "returns nil" do
        expect(nulls.placement).to be_nil
      end
    end
  end

  describe "#to_sql" do
    subject(:to_sql) { nulls.to_sql }

    context "when the placement is last" do
      it "orders the nulls at the end" do
        expect(to_sql).to eq(" NULLS LAST")
      end
    end

    context "when the placement is first" do
      let(:placement) { :first }

      it "orders the nulls at the start" do
        expect(to_sql).to eq(" NULLS FIRST")
      end
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      it "adds nothing, and the database places the nulls" do
        expect(to_sql).to eq("")
      end
    end
  end

  describe "#other_end" do
    subject(:other_end) { nulls.other_end }

    context "when the placement is last" do
      it "returns first" do
        expect(other_end).to eq(:first)
      end
    end

    context "when the placement is first" do
      let(:placement) { :first }

      it "returns last" do
        expect(other_end).to eq(:last)
      end
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      it "returns nil" do
        expect(other_end).to be_nil
      end
    end
  end

  describe "#trailing?" do
    context "when the placement is last" do
      it { is_expected.to be_trailing }
    end

    context "when the placement is first" do
      let(:placement) { :first }

      it { is_expected.not_to be_trailing }
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      it { is_expected.not_to be_trailing }
    end
  end

  describe "#read_first?" do
    context "when the placement is last" do
      it { is_expected.not_to be_read_first }
    end

    context "when the placement is first" do
      let(:placement) { :first }

      it { is_expected.to be_read_first }
    end

    context "when the placement is nil" do
      let(:placement) { nil }

      context "when the direction sorts ascending" do
        it { is_expected.not_to be_read_first }
      end

      context "when the direction sorts descending" do
        let(:direction) { JsonApiKit::Pagination::Direction.for(:desc) }

        it { is_expected.to be_read_first }
      end
    end
  end
end
