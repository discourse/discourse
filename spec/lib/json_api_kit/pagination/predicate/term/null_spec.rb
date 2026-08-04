# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Predicate::Term::Null do
  subject(:term) { described_class.new(key) }

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:bumped_at, model:) }

  describe "#comparable?" do
    it "has no value any comparison could hold against" do
      expect(term).not_to be_comparable
    end
  end

  describe "#matches" do
    subject(:matches) { term.matches }

    it "holds the row at null, which no equality would" do
      expect(matches).to eq(%("topics"."bumped_at" IS NULL))
    end
  end

  describe "#disjuncts" do
    subject(:disjuncts) { term.disjuncts([]) }

    it "offers none, since nothing sorts after null within its own group" do
      expect(disjuncts).to be_empty
    end
  end

  describe "#bound_on" do
    subject(:bounded) { term.bound_on("THE COMPARISON") }

    it "leaves the comparison unbounded, rather than bounding it to nothing" do
      expect(bounded).to eq("THE COMPARISON")
    end
  end

  describe "#bindings" do
    subject(:bindings) { term.bindings }

    it "binds nothing, having no value to bind" do
      expect(bindings).to be_empty
    end
  end
end
