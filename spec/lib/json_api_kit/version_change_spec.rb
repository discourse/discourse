# frozen_string_literal: true

module JsonApiKitSpec
  class RenameThingsLabelToName < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `label` attribute of the things resource is renamed to `name`."

    resource :things do
      renamed_attribute from: :label, to: :name
    end
  end

  class ReshapeThingsWordsToTitle < JsonApiKit::VersionChange
    version "2026-09-20"
    description "The `words` attribute of the things resource becomes `title`, one string."

    resource :things do
      renamed_attribute from: :words,
                        to: :title,
                        down: ->(title) { title.to_s.split(" ") },
                        up: ->(words) { words.to_a.join(" ") }
    end
  end

  class MergeThingsDateAndTimeIntoPostedAt < JsonApiKit::VersionChange
    version "2026-09-20"
    description "The `posted_date` and `posted_time` attributes of the things resource become `posted_at`."

    resource :things do
      merged_attributes from: %i[posted_date posted_time],
                        to: :posted_at,
                        up: ->(date, time) { "#{date} #{time}" },
                        down: ->(posted_at) { posted_at.to_s.split(" ") }
    end
  end

  class RenameThingsSortAndFilter < JsonApiKit::VersionChange
    version "2026-09-20"
    description "The things resource renames its `bumped_at` sort and its `label` filter."

    resource :things do
      renamed_sort from: :bumped_at, to: :last_posted_at
      renamed_filter from: :label, to: :name
    end
  end

  class RenameThingsAndPeople < JsonApiKit::VersionChange
    version "2026-10-01"
    description "Two resources change their names."

    resource :things do
      renamed_attribute from: :label, to: :name
    end

    resource :people do
      renamed_attribute from: :handle, to: :username
    end
  end
end

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new(__FILE__) }

  let(:change_class) { JsonApiKitSpec::RenameThingsLabelToName }
  let(:version) { JsonApiKit::ApiVersion.parse("2026-09-15") }
  let(:name) { JsonApiKit::Name::Field.new(value: "label", type: "things") }

  describe ".resource" do
    subject(:transformations) { change_class.transformations }

    it "collects a rename for each name the attribute derives" do
      expect(transformations).to all(be_a(JsonApiKit::VersionChange::Rename))
    end

    context "when the resource merges attributes" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }

      it "collects a merge for each name the attribute derives" do
        expect(transformations).to all(be_a(JsonApiKit::VersionChange::Merge))
      end
    end

    context "when the resource renames a sort and a filter" do
      let(:change_class) { JsonApiKitSpec::RenameThingsSortAndFilter }
      let(:previous_names) { transformations.map(&:from) }

      it "collects one rename for the sort and one for the filter" do
        expect(previous_names).to contain_exactly(
          JsonApiKit::Name::Sort.new(value: "bumped_at", type: "things"),
          JsonApiKit::Name::Filter.new(value: "label", type: "things"),
        )
      end
    end

    context "when a rename declares a converter" do
      subject(:declare_resource) { Class.new(described_class).resource(:things, &declarations) }

      context "when a sort rename declares an up converter" do
        let(:declarations) do
          proc { renamed_sort from: :label, to: :name, up: ->(value) { value } }
        end

        it "rejects the converter option" do
          expect { declare_resource }.to raise_error(ArgumentError, "unknown keyword: :up")
        end
      end

      context "when a sort rename declares a down converter" do
        let(:declarations) do
          proc { renamed_sort from: :label, to: :name, down: ->(value) { value } }
        end

        it "rejects the converter option" do
          expect { declare_resource }.to raise_error(ArgumentError, "unknown keyword: :down")
        end
      end

      context "when a filter rename declares an up converter" do
        let(:declarations) do
          proc { renamed_filter from: :label, to: :name, up: ->(value) { value } }
        end

        it "rejects the converter option" do
          expect { declare_resource }.to raise_error(ArgumentError, "unknown keyword: :up")
        end
      end

      context "when a filter rename declares a down converter" do
        let(:declarations) do
          proc { renamed_filter from: :label, to: :name, down: ->(value) { value } }
        end

        it "rejects the converter option" do
          expect { declare_resource }.to raise_error(ArgumentError, "unknown keyword: :down")
        end
      end
    end
  end

  describe "#version" do
    it "returns the version of the change" do
      expect(version_change.version).to eq(version)
    end
  end

  describe "#description" do
    it "returns the description of the change" do
      expect(version_change.description).to eq(
        "The `label` attribute of the things resource is renamed to `name`.",
      )
    end
  end

  describe "#current" do
    subject(:current_name) { version_change.current(name) }

    it "returns the name after the change" do
      expect(current_name).to eq(name.with(value: "name"))
    end

    context "when the name is the sort derived from the attribute" do
      let(:name) { JsonApiKit::Name::Sort.new(value: "label", type: "things") }

      it "renames it" do
        expect(current_name).to eq(name.with(value: "name"))
      end
    end

    context "when the name is the anchor derived from the attribute" do
      let(:name) { JsonApiKit::Name::Anchor.new(value: "label", type: "things") }

      it "renames it" do
        expect(current_name).to eq(name.with(value: "name"))
      end
    end

    context "when the name is a filter with the same spelling" do
      let(:name) { JsonApiKit::Name::Filter.new(value: "label", type: "things") }

      it "returns the name" do
        expect(current_name).to eq(name)
      end

      context "when the change renames the filter" do
        let(:change_class) { JsonApiKitSpec::RenameThingsSortAndFilter }

        it "returns the new name of the filter" do
          expect(current_name).to eq(name.with(value: "name"))
        end
      end
    end

    context "when the change merges the name into another" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }
      let(:name) { JsonApiKit::Name::Field.new(value: "posted_time", type: "things") }

      it "returns the name it merges into" do
        expect(current_name).to eq(name.with(value: "posted_at"))
      end
    end

    context "with several resources" do
      let(:change_class) { JsonApiKitSpec::RenameThingsAndPeople }
      let(:other_name) { JsonApiKit::Name::Field.new(value: "handle", type: "people") }

      it "renames the names of every resource" do
        expect([version_change.current(name), version_change.current(other_name)]).to eq(
          [name.with(value: "name"), other_name.with(value: "username")],
        )
      end
    end
  end

  describe "#current_attributes" do
    subject(:current_attributes) { version_change.current_attributes(attributes) }

    let(:attributes) { { name => "A", other_name => "B" } }
    let(:other_name) { JsonApiKit::Name::Field.new(value: "size", type: "things") }

    it "returns a renamed attribute under its current name" do
      expect(current_attributes).to include(name.with(value: "name") => "A")
    end

    it "keeps an attribute the change does not rename" do
      expect(current_attributes).to include(other_name => "B")
    end

    context "when the change merges two attributes" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }
      let(:attributes) { { name => "2026-08-01", other_name => "00:00:00" } }
      let(:name) { JsonApiKit::Name::Field.new(value: "posted_date", type: "things") }
      let(:other_name) { JsonApiKit::Name::Field.new(value: "posted_time", type: "things") }

      it "returns one attribute under the name they merge into" do
        expect(current_attributes).to eq(name.with(value: "posted_at") => "2026-08-01 00:00:00")
      end
    end

    context "when the change reshapes the value" do
      let(:change_class) { JsonApiKitSpec::ReshapeThingsWordsToTitle }
      let(:attributes) { { name => %w[Bands of a listing] } }
      let(:name) { JsonApiKit::Name::Field.new(value: "words", type: "things") }

      it "returns the value in its current shape" do
        expect(current_attributes).to eq(name.with(value: "title") => "Bands of a listing")
      end

      context "when the value is null" do
        let(:attributes) { { name => nil } }

        it "returns the value the converter gives for null" do
          expect(current_attributes).to eq(name.with(value: "title") => "")
        end
      end
    end
  end

  describe "#previous" do
    subject(:previous_name) { version_change.previous(name) }

    let(:name) { JsonApiKit::Name::Field.new(value: "name", type: "things") }

    it "returns the name before the change" do
      expect(previous_name).to eq(name.with(value: "label"))
    end

    context "when the change merges several names into the name" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }
      let(:name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "things") }

      it "returns the first of them" do
        expect(previous_name).to eq(name.with(value: "posted_date"))
      end
    end
  end

  describe "#previous_names" do
    subject(:previous_names) { version_change.previous_names(name) }

    let(:name) { JsonApiKit::Name::Field.new(value: "name", type: "things") }

    it "returns the name before the change" do
      expect(previous_names).to eq([name.with(value: "label")])
    end

    context "when the change merges several names into the name" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }
      let(:name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "things") }

      it "returns every one of them" do
        expect(previous_names).to eq(
          [name.with(value: "posted_date"), name.with(value: "posted_time")],
        )
      end
    end
  end

  describe "#previous_attributes" do
    subject(:previous_attributes) { version_change.previous_attributes(attributes) }

    let(:attributes) { { name => "A", other_name => "B" } }
    let(:name) { JsonApiKit::Name::Field.new(value: "name", type: "things") }
    let(:other_name) { JsonApiKit::Name::Field.new(value: "size", type: "things") }

    it "returns a renamed attribute under its name before the change" do
      expect(previous_attributes).to include(name.with(value: "label") => "A")
    end

    it "keeps an attribute the change does not rename" do
      expect(previous_attributes).to include(other_name => "B")
    end

    context "when the change merges two attributes" do
      let(:change_class) { JsonApiKitSpec::MergeThingsDateAndTimeIntoPostedAt }
      let(:attributes) { { name => "2026-08-01 00:00:00" } }
      let(:name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "things") }

      it "returns the two attributes under their names before the change" do
        expect(previous_attributes).to eq(
          name.with(value: "posted_date") => "2026-08-01",
          name.with(value: "posted_time") => "00:00:00",
        )
      end
    end

    context "when the change reshapes the value" do
      let(:change_class) { JsonApiKitSpec::ReshapeThingsWordsToTitle }
      let(:attributes) { { name => "Bands of a listing" } }
      let(:name) { JsonApiKit::Name::Field.new(value: "title", type: "things") }

      it "returns the value in its shape before the change" do
        expect(previous_attributes).to eq(name.with(value: "words") => %w[Bands of a listing])
      end

      context "when the value is null" do
        let(:attributes) { { name => nil } }

        it "returns the value the converter gives for null" do
          expect(previous_attributes).to eq(name.with(value: "words") => [])
        end
      end
    end
  end
end
