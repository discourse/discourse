# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Predicate::Term::Null do
  subject(:term) { described_class.new(key) }

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:) }

  describe "#comparable?" do
    it { is_expected.not_to be_comparable }
  end

  describe "#matches" do
    subject(:matches) { term.matches }

    it "matches a row that holds null" do
      expect(matches).to eq(%("topics"."bumped_at" IS NULL))
    end
  end

  describe "#disjuncts" do
    subject(:disjuncts) { term.disjuncts([]) }

    context "when the order reads the nulls last" do
      it "returns no comparison" do
        expect(disjuncts).to be_empty
      end
    end

    context "when the order reads the nulls first" do
      let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:, nulls: :first) }

      it "returns one comparison for the rows that hold a value" do
        expect(disjuncts).to eq([%(("topics"."bumped_at" IS NOT NULL))])
      end
    end
  end

  describe "#bound_on" do
    subject(:bounded_comparison) { term.bound_on("THE COMPARISON") }

    it "adds no bound to the comparison" do
      expect(bounded_comparison).to eq("THE COMPARISON")
    end
  end

  describe "#bindings" do
    subject(:bindings) { term.bindings }

    it "binds no value" do
      expect(bindings).to be_empty
    end
  end
end
