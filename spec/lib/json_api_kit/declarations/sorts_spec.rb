# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sorts do
  subject(:sorts) { described_class.new(declarations, schema:, default: default_sort, unique_by:) }

  let(:schema) { JsonApiKit::Schema.new(Topic) }
  let(:sort_class) { JsonApiKit::Declarations::Sort }
  let(:declarations) do
    [sort_class.new(:created_at), sort_class.new(:ran_at, column: :last_posted_at)]
  end
  let(:default_sort) { {} }
  let(:unique_by) { [] }

  describe "#fetch" do
    subject(:sort) { sorts.fetch("created_at") }

    it "returns that sort" do
      expect(sort.name).to eq("created_at")
    end

    context "when the resource declares no sort by that name" do
      subject(:sort) { sorts.fetch("secrets") }

      it "refuses the request" do
        expect { sort }.to raise_error(KeyError)
      end
    end
  end

  describe "#keyset" do
    subject(:keyset) { sorts.keyset(ordering) }

    let(:ordering) { { "created_at" => :desc } }

    it "orders by that sort" do
      expect(keyset.leading.name).to eq(:created_at)
    end

    it "reads it in that direction" do
      expect(keyset.leading.direction.to_sym).to eq(:desc)
    end

    it "breaks its ties by the primary key of the model" do
      expect(keyset.keys.last.name).to eq(:id)
    end

    it "reads that key in the direction of the leading key" do
      expect(keyset.keys.last.direction.to_sym).to eq(:desc)
    end

    context "when the ordering holds two sorts" do
      let(:ordering) { { "ran_at" => :asc, "created_at" => :desc } }

      it "orders by each one in that sequence" do
        expect(keyset.keys.map(&:name)).to eq(%i[last_posted_at created_at id])
      end
    end

    context "when the resource declares no sort by that name" do
      let(:ordering) { { "secrets" => :desc } }

      it "refuses the request" do
        expect { keyset }.to raise_error(KeyError)
      end
    end

    context "when only the default sort exists" do
      let(:ordering) { {} }
      let(:default_sort) { { ran_at: :desc } }

      it "orders by the sort the resource declares" do
        expect(keyset.keys.map(&:name)).to eq(%i[last_posted_at id])
      end
    end

    context "when neither the ordering nor the default sort exists" do
      let(:ordering) { {} }

      it "orders by the key that makes each row unique, upwards" do
        expect(keyset.keys.map { [it.name, it.direction.to_sym] }).to eq([%i[id asc]])
      end
    end

    context "when the resource declares a unique key of its own" do
      let(:unique_by) { %i[title id] }

      it "breaks ties by each column of that key in order" do
        expect(keyset.keys.map(&:name)).to eq(%i[created_at title id])
      end
    end

    context "when the resource declares one column as that key" do
      let(:unique_by) { :title }

      it "breaks ties by that column" do
        expect(keyset.keys.map(&:name)).to eq(%i[created_at title])
      end
    end

    context "when the ordering holds the key that breaks ties" do
      let(:ordering) { { "created_at" => :desc, "id" => :asc } }
      let(:declarations) { [sort_class.new(:created_at), sort_class.new(:id)] }

      it "reads that key once in that direction" do
        expect(keyset.keys.map { [it.name, it.direction.to_sym] }).to eq(
          [%i[created_at desc], %i[id asc]],
        )
      end
    end
  end
end
