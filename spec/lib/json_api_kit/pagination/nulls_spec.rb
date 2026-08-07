# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Nulls do
  subject(:nulls) { described_class.for(placement, direction:) }

  let(:placement) { :last }
  let(:direction) { JsonApiKit::Pagination::Direction.for(:asc) }

  describe ".for" do
    context "with a placement nulls cannot sort at" do
      let(:placement) { :middle }

      it "refuses it where the key is declared" do
        expect { nulls }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#expected?" do
    it "expects the nulls a placement was declared for" do
      expect(nulls).to be_expected
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "expects none" do
        expect(nulls).not_to be_expected
      end
    end
  end

  describe "#placement" do
    subject(:declared) { nulls.placement }

    it "is the end it was declared at, which is what another reading is built from" do
      expect(declared).to eq(:last)
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "is nothing to declare" do
        expect(declared).to be_nil
      end
    end
  end

  describe "#to_sql" do
    subject(:to_sql) { nulls.to_sql }

    it "names the end nulls sort at" do
      expect(to_sql).to eq(" NULLS LAST")
    end

    context "when nulls sort first" do
      let(:placement) { :first }

      it "names that end instead" do
        expect(to_sql).to eq(" NULLS FIRST")
      end
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "names none, an unread end constraining the index for nothing" do
        expect(to_sql).to eq("")
      end
    end
  end

  describe "#reversed" do
    subject(:reversed) { nulls.reversed }

    it "declares the other end, where reversing the reading leaves them" do
      expect(reversed).to eq(:first)
    end

    context "when nulls sort first" do
      let(:placement) { :first }

      it "declares them last" do
        expect(reversed).to eq(:last)
      end
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "declares nothing either way" do
        expect(reversed).to be_nil
      end
    end
  end

  describe "#trailing?" do
    it "trails the values, so a comparison has to take those rows in" do
      expect(nulls).to be_trailing
    end

    context "when nulls sort first" do
      let(:placement) { :first }

      it "trails nothing" do
        expect(nulls).not_to be_trailing
      end
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "has no rows to trail with" do
        expect(nulls).not_to be_trailing
      end
    end
  end

  describe "#read_first?" do
    it "is read after the values it sorts behind" do
      expect(nulls).not_to be_read_first
    end

    context "when nulls sort first" do
      let(:placement) { :first }

      it "is read before them" do
        expect(nulls).to be_read_first
      end
    end

    context "with no placement declared" do
      let(:placement) { nil }

      it "is read where the database puts nulls ascending, which is last" do
        expect(nulls).not_to be_read_first
      end

      context "when the key sorts descending" do
        let(:direction) { JsonApiKit::Pagination::Direction.for(:desc) }

        it "is read where the database puts them descending, which is first" do
          expect(nulls).to be_read_first
        end
      end
    end
  end
end
