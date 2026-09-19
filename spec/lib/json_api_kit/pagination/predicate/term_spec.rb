# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Predicate::Term do
  subject(:term) { described_class.for(key, value) }

  let(:model) { Topic }
  let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:) }
  let(:descending_key) do
    JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:, direction: :desc)
  end
  let(:value) { "2026-08-03T12:00:00.123456Z" }

  describe ".for" do
    it "returns a term that compares the value" do
      expect(term).to be_an_instance_of(described_class)
    end

    context "when the cursor holds no value for the key" do
      let(:value) { nil }

      it "returns a term that compares nothing" do
        expect(term).to be_an_instance_of(described_class::Null)
      end
    end

    context "when the cursor holds false for the key" do
      let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:closed, model:) }
      let(:value) { false }

      it "returns a term that compares the false value" do
        expect(term).to be_an_instance_of(described_class)
      end
    end
  end

  describe "#comparable?" do
    it { is_expected.to be_comparable }

    context "when the key sorts its nulls last" do
      let(:key) { JsonApiKit::Pagination::Keyset::Key.new(:pinned_at, model:, nulls: :last) }

      it { is_expected.not_to be_comparable }
    end
  end

  describe "#placeholder" do
    subject(:placeholder) { term.placeholder }

    it "returns the key name as the placeholder" do
      expect(placeholder).to eq(":created_at")
    end
  end

  describe "#matches" do
    subject(:matches) { term.matches }

    it "matches a row that holds the cursor value" do
      expect(matches).to eq(%("topics"."created_at" = :created_at))
    end
  end

  describe "#disjuncts" do
    subject(:disjuncts) { term.disjuncts(matched_terms) }

    let(:matched_terms) { [] }

    it "returns one comparison for the rows after the cursor value" do
      expect(disjuncts).to eq([%(("topics"."created_at" > :created_at))])
    end

    context "when the keys before it match the cursor" do
      let(:matched_terms) do
        [described_class.for(JsonApiKit::Pagination::Keyset::Key.new(:id, model:), 12)]
      end

      it "adds an equality for each key before it" do
        expect(disjuncts).to eq([%(("topics"."id" = :id AND "topics"."created_at" > :created_at))])
      end
    end

    context "when the key sorts descending" do
      let(:key) { descending_key }

      it "compares the value the other way" do
        expect(disjuncts).to eq([%(("topics"."created_at" < :created_at))])
      end
    end
  end

  describe "#bound_on" do
    subject(:bounded_comparison) { term.bound_on("THE COMPARISON") }

    it "bounds the comparison at the cursor value, not past it" do
      expect(bounded_comparison).to eq(%("topics"."created_at" >= :created_at AND (THE COMPARISON)))
    end

    context "when the key sorts descending" do
      let(:key) { descending_key }

      it "bounds the comparison the other way" do
        expect(bounded_comparison).to eq(
          %("topics"."created_at" <= :created_at AND (THE COMPARISON)),
        )
      end
    end
  end

  describe "#bindings" do
    subject(:bindings) { term.bindings }

    before { allow(key).to receive(:cast).with(value).and_return("the value of the column") }

    it "binds the value the key casts" do
      expect(bindings).to eq(created_at: "the value of the column")
    end
  end
end
