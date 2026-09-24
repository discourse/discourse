# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::TypeRenames do
  subject(:type_renames) { described_class.new(renames) }

  let(:previous_type) { JsonApiKit::Name::Type.new(value: "pictures") }
  let(:current_type) { JsonApiKit::Name::Type.new(value: "images") }
  let(:rename) { JsonApiKit::VersionChange::TypeRename.new(from: previous_type, to: current_type) }
  let(:renames) { [rename] }

  describe "#current" do
    subject(:current) { type_renames.current(type) }

    let(:type) { "pictures" }

    it "returns the current type string" do
      expect(current).to eq("images")
    end

    context "when the type has no rename" do
      let(:type) { "users" }

      it "preserves the type" do
        expect(current).to eq("users")
      end
    end

    context "when the collection is empty" do
      let(:renames) { [] }

      it "preserves the type" do
        expect(current).to eq("pictures")
      end
    end
  end

  describe "#previous" do
    subject(:previous) { type_renames.previous(type) }

    let(:type) { "images" }

    it "returns the historical type string" do
      expect(previous).to eq("pictures")
    end

    context "when the type has no rename" do
      let(:type) { "users" }

      it "preserves the type" do
        expect(previous).to eq("users")
      end
    end

    context "when the collection is empty" do
      let(:renames) { [] }

      it "preserves the type" do
        expect(previous).to eq("images")
      end
    end
  end
end

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-02_rename_types.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-02"
      description "Things become items."

      resource :items do
        merged_attributes from: %i[first last],
                          to: :name,
                          up: ->(first, last) { "#{first} #{last}" },
                          down: ->(name) { name.split(" ") }
      end

      renamed_type from: :things, to: :items
    end
  end
  let(:field) { JsonApiKit::Name::Field.new(value: "first", type: "things") }

  describe ".renamed_type" do
    subject(:declare_type) { Class.new(described_class).renamed_type(**options) }

    let(:options) { { from: :things, to: :items, up: ->(value) { value } } }

    it "rejects an up converter" do
      expect { declare_type }.to raise_error(ArgumentError, "unknown keyword: :up")
    end

    context "when the declaration supplies a down converter" do
      let(:options) { { from: :things, to: :items, down: ->(value) { value } } }

      it "rejects a down converter" do
        expect { declare_type }.to raise_error(ArgumentError, "unknown keyword: :down")
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 5)) }

    it "accepts a type change with field changes" do
      expect { verify }.not_to raise_error
    end

    context "when one type has two targets" do
      before { change_class.renamed_type from: :things, to: :widgets }

      it "rejects the repeated source" do
        expect { verify }.to raise_error(ArgumentError, /changes things twice/)
      end
    end

    context "when two types have one target" do
      before { change_class.renamed_type from: :widgets, to: :items }

      it "rejects the repeated target" do
        expect { verify }.to raise_error(ArgumentError, /changes two names into items/)
      end
    end
  end

  describe "#current_resource_type" do
    subject(:type) { version_change.current_resource_type(previous_type) }

    let(:previous_type) { "things" }

    it "returns the type after the change" do
      expect(type).to eq("items")
    end

    context "when the resource has no type rename" do
      let(:previous_type) { "people" }

      it "preserves the type" do
        expect(type).to eq("people")
      end
    end
  end

  describe "#previous_resource_type" do
    subject(:type) { version_change.previous_resource_type(current_type) }

    let(:current_type) { "items" }

    it "returns the type before the change" do
      expect(type).to eq("things")
    end

    context "when the resource has no type rename" do
      let(:current_type) { "people" }

      it "preserves the type" do
        expect(type).to eq("people")
      end
    end
  end

  describe "#current_names" do
    subject(:current_names) { version_change.current_names(name) }

    let(:name) { field }

    it "changes the owning type before the field name" do
      expect(current_names).to eq([field.with(value: "name", type: "items")])
    end

    context "when the name is a type" do
      let(:name) { JsonApiKit::Name::Type.new(value: "things") }

      it "changes the type value" do
        expect(current_names).to eq([name.with(value: "items")])
      end
    end

    context "when the name has no owning type" do
      let(:name) { JsonApiKit::Name::Member.new(value: "things") }

      it "preserves the member name" do
        expect(current_names).to eq([name])
      end
    end

    context "when the name belongs to another type" do
      let(:name) { field.with(type: "people") }

      it "preserves the field name" do
        expect(current_names).to eq([name])
      end
    end

    context "when a relationship has the same spelling as the old type" do
      let(:name) { JsonApiKit::Name::Relationship.new(value: "things", type: "things") }

      it "changes only the owning type" do
        expect(current_names).to eq([name.with(type: "items")])
      end
    end

    context "when a sort path contains the old type" do
      let(:name) { JsonApiKit::Name::Sort.new(value: "things.first", type: "things") }

      it "preserves the path" do
        expect(current_names).to eq([name.with(type: "items")])
      end
    end
  end

  describe "#current_attributes" do
    subject(:current_attributes) { version_change.current_attributes(attributes) }

    let(:attributes) { { field.with(value: "last") => "B", field => "A" } }

    it "changes the type before merging values in declaration order" do
      expect(current_attributes).to eq(field.with(value: "name", type: "items") => "A B")
    end

    context "when a converter fails after the type changes" do
      let(:change_class) do
        Class.new(described_class) do
          renamed_type from: :things, to: :items

          resource :items do
            renamed_attribute from: :former_first, to: :first
            merged_attributes from: %i[first last],
                              to: :name,
                              up: ->(first, last) do
                                [first.fetch(:label), last.fetch(:label)].join(" ")
                              end,
                              down: ->(name) { name.split(" ").map { { label: it } } }
          end
        end
      end

      it "reverses the type phase without reversing the field phase" do
        expect { current_attributes }.to raise_error(
          having_attributes(names: [field, field.with(value: "last")]),
        )
      end
    end
  end

  describe "#previous_names" do
    subject(:previous_names) { version_change.previous_names(name) }

    let(:name) { field.with(value: "name", type: "items") }

    it "reverses the type change for each merge component" do
      expect(previous_names).to eq([field, field.with(value: "last")])
    end

    context "when the name is a type" do
      let(:name) { JsonApiKit::Name::Type.new(value: "items") }

      it "reverses the type change" do
        expect(previous_names).to eq([name.with(value: "things")])
      end
    end
  end

  describe "#previous_attributes" do
    subject(:previous_attributes) { version_change.previous_attributes(attributes) }

    let(:attributes) { { field.with(value: "name", type: "items") => "A B" } }

    it "splits the value before reversing the type change" do
      expect(previous_attributes).to eq(field => "A", field.with(value: "last") => "B")
    end
  end
end
