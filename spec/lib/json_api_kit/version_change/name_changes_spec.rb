# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::NameChanges do
  subject(:name_changes) { described_class.new(changes) }

  let(:previous_type) { JsonApiKit::Name::Type.new(value: "pictures") }
  let(:current_type) { previous_type.with(value: "images") }
  let(:rename) { JsonApiKit::VersionChange::TypeRename.new(from: previous_type, to: current_type) }
  let(:changes) { [rename] }

  describe "#current_names" do
    subject(:current_names) { name_changes.current_names(name) }

    let(:name) { previous_type }

    it "returns the destination names" do
      expect(current_names).to eq([current_type])
    end

    context "when the name has no change" do
      let(:name) { previous_type.with(value: "users") }

      it "preserves the name" do
        expect(current_names).to eq([name])
      end
    end

    context "when another kind of name has the same value" do
      let(:name) { JsonApiKit::Name::Member.new(value: "pictures") }

      it "preserves the unrelated name" do
        expect(current_names).to eq([name])
      end
    end
  end

  describe "#previous_names" do
    subject(:previous_names) { name_changes.previous_names(name) }

    let(:name) { current_type }

    it "returns the source names" do
      expect(previous_names).to eq([previous_type])
    end

    context "when the name has no change" do
      let(:name) { current_type.with(value: "users") }

      it "preserves the name" do
        expect(previous_names).to eq([name])
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { name_changes.verify! }

    it "accepts distinct sources and destinations" do
      expect { verify }.not_to raise_error
    end

    context "when the collection is empty" do
      let(:changes) { [] }

      it "accepts the collection" do
        expect { verify }.not_to raise_error
      end
    end

    context "when two changes share a source" do
      let(:changes) { [rename, rename.with(to: current_type.with(value: "uploads"))] }

      it "reports the repeated source" do
        expect { verify }.to raise_error(described_class::Conflict, "changes pictures twice.")
      end
    end

    context "when two changes share a destination" do
      let(:changes) { [rename, rename.with(from: previous_type.with(value: "uploads"))] }

      it "reports the repeated destination" do
        expect { verify }.to raise_error(
          described_class::Conflict,
          "changes two names into images.",
        )
      end
    end
  end
end
