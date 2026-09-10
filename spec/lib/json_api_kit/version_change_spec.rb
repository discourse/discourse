# frozen_string_literal: true

module JsonApiKitSpec
  class RenameThingsLabelToName < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `label` attribute of the things resource is renamed to `name`."

    resource :things do
      renamed_attribute from: :label, to: :name
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
  subject(:change) { JsonApiKitSpec::RenameThingsLabelToName.new(__FILE__) }

  let(:version) { JsonApiKit::ApiVersion.parse("2026-09-15") }
  let(:later_version) { JsonApiKit::ApiVersion.parse("2026-10-01") }
  let(:fixtures) { Rails.root.join("spec/fixtures/json_api_kit") }
  let(:name) { JsonApiKit::Name::Field.new(value: "label", type: "things") }

  describe ".read" do
    subject(:changes) { described_class.read(fixtures.join(directory)) }

    let(:directory) { "api_changes" }

    it "returns the change of each file, oldest version first" do
      expect(changes.map(&:class)).to eq([RenameWidgetsLabelToName, AnotherWidgetsChange])
    end

    it "gives each change the file it came from" do
      expect(changes.first.source.to_s).to end_with("2026-09-01_rename_widgets_label_to_name.rb")
    end

    context "when the file name does not start with the version" do
      let(:directory) { "api_changes_misdated" }

      it do
        expect { changes }.to raise_error(ArgumentError, /must start with the version 2026-09-02/)
      end
    end

    context "when a change is dated in the future" do
      let(:directory) { "api_changes_in_the_future" }

      it { expect { changes }.to raise_error(ArgumentError, /in the future/) }
    end

    context "when the version of a change is not a date" do
      let(:directory) { "api_changes_with_a_bad_date" }

      it { expect { changes }.to raise_error(ArgumentError, /is not a date/) }
    end

    context "when the class of a change does not match its file" do
      let(:directory) { "api_changes_misnamed" }

      it { expect { changes }.to raise_error(NameError, /MisnamedWidgetsChange/) }
    end

    context "when a change has no version" do
      let(:directory) { "api_changes_without_version" }

      it { expect { changes }.to raise_error(ArgumentError, /has no version/) }
    end

    context "when a change is dated on or before the first release" do
      let(:directory) { "api_changes_before_first_release" }

      it { expect { changes }.to raise_error(ArgumentError, /on or before the first release/) }
    end

    context "when a change has no description" do
      let(:directory) { "api_changes_without_description" }

      it { expect { changes }.to raise_error(ArgumentError, /has no description/) }
    end
  end

  describe ".after" do
    subject(:changes) { described_class.after(pin) }

    let(:pin) { version }
    let(:later_change) { JsonApiKitSpec::RenameThingsAndPeople.new(__FILE__) }

    before { allow(described_class).to receive(:all).and_return([change, later_change]) }

    it "returns the changes dated after the version" do
      expect(changes).to eq([later_change])
    end

    context "when the version is the latest" do
      let(:pin) { later_version }

      it "returns no change" do
        expect(changes).to be_empty
      end
    end
  end

  describe "#version" do
    it "returns the version of the change" do
      expect(change.version).to eq(version)
    end
  end

  describe "#description" do
    it "returns the description of the change" do
      expect(change.description).to eq(
        "The `label` attribute of the things resource is renamed to `name`.",
      )
    end
  end

  describe "#current" do
    subject(:current_name) { change.current(name) }

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

    context "when the name is a filter with that name" do
      let(:name) { JsonApiKit::Name::Filter.new(value: "label", type: "things") }

      it "returns the name" do
        expect(current_name).to eq(name)
      end
    end

    context "with several resources" do
      subject(:change) { JsonApiKitSpec::RenameThingsAndPeople.new(__FILE__) }

      let(:other_name) { JsonApiKit::Name::Field.new(value: "handle", type: "people") }

      it "renames the names of every resource" do
        expect([change.current(name), change.current(other_name)]).to eq(
          [name.with(value: "name"), other_name.with(value: "username")],
        )
      end
    end
  end

  describe "#previous" do
    subject(:previous_name) { change.previous(name) }

    let(:name) { JsonApiKit::Name::Field.new(value: "name", type: "things") }

    it "returns the name before the change" do
      expect(previous_name).to eq(name.with(value: "label"))
    end
  end

  describe "#introduces?" do
    context "when the change renames another name to this one" do
      let(:name) { JsonApiKit::Name::Field.new(value: "name", type: "things") }

      it { expect(change).to be_introduces(name) }
    end

    context "when the change renames this name away" do
      it { expect(change).not_to be_introduces(name) }
    end
  end
end
