# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Declaration::RenamedName do
  subject(:declaration) do
    described_class.new("things", kinds, from: :bumped_at, to: :last_posted_at)
  end

  let(:kinds) { [JsonApiKit::Name::Sort] }

  describe "#transformations" do
    subject(:transformations) { declaration.transformations }

    let(:rename) { transformations.sole }

    it "returns one rename of that kind" do
      expect(transformations).to contain_exactly(
        an_object_having_attributes(
          from: JsonApiKit::Name::Sort.new(value: "bumped_at", type: "things"),
          to: JsonApiKit::Name::Sort.new(value: "last_posted_at", type: "things"),
        ),
      )
    end

    it "preserves the value through the up converter" do
      expect(rename.up.call("a")).to eq("a")
    end

    it "preserves the value through the down converter" do
      expect(rename.down.call("a")).to eq("a")
    end

    context "when the kind is a filter" do
      let(:kinds) { [JsonApiKit::Name::Filter] }
      let(:previous_names) { transformations.map(&:from) }

      it "returns one rename of a filter" do
        expect(previous_names).to contain_exactly(
          JsonApiKit::Name::Filter.new(value: "bumped_at", type: "things"),
        )
      end
    end
  end
end
