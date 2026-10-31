# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Declarations::Sorts do
  subject(:sorts) { described_class.new(collection, builder:, unique_by:) }

  let(:builder) { resource.adapter }
  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
      end
      .new(guardian: Guardian.new)
  end
  let(:sort_class) { JsonApiKit::Declarations::Sort }
  let(:declarations) do
    [sort_class.new(:created_at), sort_class.new(:ran_at, column: :last_posted_at)]
  end
  let(:collection) { JsonApiKit::Declarations::Sorts.new(declarations) }
  let(:unique_by) { [] }

  describe "#keyset" do
    subject(:keyset) { sorts.keyset(ordering) }

    let(:ordering) { { "created_at" => :desc } }
    let(:key_ordering) { keyset.keys.map { [it.name, it.direction.to_sym] } }

    it "builds a stable descending order" do
      expect(key_ordering).to eq([%i[created_at desc], %i[id desc]])
    end

    context "when the ordering holds two sorts" do
      let(:ordering) { { "ran_at" => :asc, "created_at" => :desc } }

      it "orders by each one in that sequence" do
        expect(key_ordering).to eq([%i[last_posted_at asc], %i[created_at desc], %i[id asc]])
      end
    end

    context "when the resource declares no sort by that name" do
      let(:ordering) { { "secrets" => :desc } }

      it "refuses the request" do
        expect { keyset }.to raise_error(KeyError)
      end
    end

    context "when the ordering is empty" do
      let(:ordering) { {} }

      it "orders by the unique key in ascending order" do
        expect(key_ordering).to eq([%i[id asc]])
      end
    end

    context "when the resource declares a unique key of its own" do
      let(:unique_by) { %i[title id] }

      it "breaks ties by each column of that key in order" do
        expect(key_ordering).to eq([%i[created_at desc], %i[title desc], %i[id desc]])
      end
    end

    context "when the resource declares one column as that key" do
      let(:unique_by) { :title }

      it "breaks ties by that column" do
        expect(key_ordering).to eq([%i[created_at desc], %i[title desc]])
      end
    end

    context "when the ordering holds the key that breaks ties" do
      let(:ordering) { { "created_at" => :desc, "id" => :asc } }
      let(:declarations) { [sort_class.new(:created_at), sort_class.new(:id)] }

      it "reads that key once in that direction" do
        expect(key_ordering).to eq([%i[created_at desc], %i[id asc]])
      end
    end
  end
end
