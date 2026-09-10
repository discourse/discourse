# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Family::Sort::Keys do
  subject(:keys) { described_class.parse(value, path) }

  let(:value) { "postedDate,-title" }
  let(:path) { ["sort"] }
  let(:declared_names) do
    { "postedDate" => "posted_at", "postedTime" => "posted_at", "title" => "title" }
  end

  describe ".parse" do
    subject(:declared_sort) { keys.declare { it.name } }

    it "returns the keys of a list with their directions" do
      expect(declared_sort).to eq("postedDate" => :asc, "title" => :desc)
    end

    context "when the sort is a hash" do
      let(:value) { { "postedDate" => "asc" } }

      it "returns the keys with the directions as they came" do
        expect(declared_sort).to eq("postedDate" => "asc")
      end
    end

    context "when the sort is an array" do
      let(:value) { %w[postedDate] }

      it "returns nothing" do
        expect(keys).to be_nil
      end
    end
  end

  describe "#declare" do
    subject(:declared_sort) { keys.declare { declared_names.fetch(it.name) } }

    it "returns the declared names with their directions" do
      expect(declared_sort).to eq("posted_at" => :asc, "title" => :desc)
    end

    context "when two keys declare one name" do
      let(:value) { "postedDate,postedTime" }

      it "returns that name once" do
        expect(declared_sort).to eq("posted_at" => :asc)
      end

      context "when their directions differ" do
        let(:value) { "postedDate,-postedTime" }

        it "raises two directions on the sort" do
          expect { declared_sort }.to raise_error(
            JsonApiKit::Request::Family::Sort::TwoDirections,
            /postedDate and postedTime/,
          )
        end

        it "points at the sort parameter" do
          expect { declared_sort }.to raise_error(having_attributes(source: { parameter: "sort" }))
        end
      end
    end
  end
end
