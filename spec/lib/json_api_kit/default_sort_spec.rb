# frozen_string_literal: true

RSpec.describe JsonApiKit::DefaultSort do
  subject(:default_sort) { described_class.new("topics", ordering) }

  let(:ordering) { { created_at: :desc, title: :asc } }

  describe ".new" do
    context "when a direction is invalid" do
      let(:ordering) { { created_at: :sideways } }

      it "rejects the direction" do
        expect { default_sort }.to raise_error(ArgumentError, /unknown direction: sideways/)
      end
    end
  end

  describe "#ordering" do
    it "normalizes sort names" do
      expect(default_sort.ordering).to eq("created_at" => :desc, "title" => :asc)
    end
  end

  describe "#convert_names" do
    subject(:converted) { default_sort.convert_names { it.convert { |value| "new_#{value}" } } }

    it "translates the resource type" do
      expect(converted.type).to eq("new_topics")
    end

    it "preserves the ordering of translated sort names" do
      expect(converted.ordering.to_a).to eq([["new_created_at", :desc], ["new_title", :asc]])
    end

    context "when two names become one with conflicting directions" do
      subject(:converted) do
        default_sort.convert_names do |name|
          case name
          when JsonApiKit::Name::Sort
            name.with(value: "combined")
          else
            name
          end
        end
      end

      it "rejects the conflicting default" do
        expect { converted }.to raise_error(ArgumentError, /conflicting directions/)
      end
    end
  end
end
