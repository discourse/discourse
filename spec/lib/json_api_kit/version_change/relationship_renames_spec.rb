# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange do
  describe ".resource" do
    subject(:transformations) { change_class.transformations }

    let(:change_class) { Class.new(described_class).tap { it.resource(:topics, &declarations) } }
    let(:declarations) { proc { renamed_relationship from: :author, to: :writer } }
    let(:previous_names) { transformations.flat_map(&:previous_names) }

    it "registers the relationship and its fieldset name" do
      expect(previous_names).to contain_exactly(
        JsonApiKit::Name::Relationship.new(value: "author", type: "topics"),
        JsonApiKit::Name::Field.new(value: "author", type: "topics"),
      )
    end

    context "when the declaration supplies an up converter" do
      let(:declarations) do
        proc { renamed_relationship from: :author, to: :writer, up: ->(value) { value } }
      end

      it "rejects the converter" do
        expect { transformations }.to raise_error(ArgumentError, "unknown keyword: :up")
      end
    end

    context "when the declaration supplies a down converter" do
      let(:declarations) do
        proc { renamed_relationship from: :author, to: :writer, down: ->(value) { value } }
      end

      it "rejects the converter" do
        expect { transformations }.to raise_error(ArgumentError, "unknown keyword: :down")
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    let(:version_change) { change_class.new("2026-09-01_rename_relationships.rb") }
    let(:change_class) do
      Class.new(described_class) do
        version "2026-09-01"
        description "The author relationship becomes writer."
        resource :topics do
          renamed_relationship from: :author, to: :writer
        end
      end
    end

    before { freeze_time(Date.new(2026, 9, 3)) }

    context "when an attribute uses the same source name" do
      before do
        change_class.resource(:topics) { renamed_attribute from: :author, to: :display_name }
      end

      it "rejects the ambiguous fieldset name" do
        expect { verify }.to raise_error(ArgumentError, /changes author twice/)
      end
    end

    context "when an attribute uses the same target name" do
      before { change_class.resource(:topics) { renamed_attribute from: :title, to: :writer } }

      it "rejects the conflicting fieldset target" do
        expect { verify }.to raise_error(ArgumentError, /changes two names into writer/)
      end
    end
  end
end
