# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChanges do
  let(:fixtures) { Rails.root.join("spec/fixtures/json_api_kit") }

  before { freeze_time(Date.new(2026, 9, 10)) }

  describe ".core" do
    subject(:core_changes) { collection_class.core }

    let(:collection_class) { Class.new(described_class) }

    before { allow(collection_class).to receive(:load).and_call_original }

    it "loads the core change directory" do
      core_changes
      expect(collection_class).to have_received(:load).with(described_class::CHANGES_DIRECTORY)
    end

    it "reuses the collection across calls" do
      expect(core_changes).to equal(collection_class.core)
    end
  end

  describe ".load" do
    subject(:changes) { described_class.load(fixtures.join(directory)) }

    let(:directory) { "api_changes" }

    it "returns the change of each file, oldest version first" do
      expect(changes.map(&:class)).to eq([RenameWidgetsLabelToName, AnotherWidgetsChange])
    end

    it "gives each change the file it came from" do
      expect(changes.first.source.to_s).to end_with("2026-09-01_rename_widgets_label_to_name.rb")
    end

    context "when the same directory is loaded again" do
      let(:previous_class) { described_class.load(fixtures.join(directory)).first.class }

      before { previous_class }

      it "replaces the previous class" do
        expect(changes.first.class).not_to equal(previous_class)
      end
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

    context "when a change renames one name twice" do
      let(:directory) { "api_changes_with_two_renames_from_one_name" }

      it { expect { changes }.to raise_error(ArgumentError, /changes label twice/) }
    end

    context "when a change renames two names to one name" do
      let(:directory) { "api_changes_with_two_renames_to_one_name" }

      it { expect { changes }.to raise_error(ArgumentError, /changes two names into title/) }
    end
  end

  describe "#after" do
    subject(:changes_after_pin) { version_changes.after(pin) }

    let(:version_changes) { described_class.load(fixtures.join("api_changes")) }
    let(:pin) { JsonApiKit::ApiVersion.parse("2026-09-01") }

    it "returns only changes after the pin" do
      expect(changes_after_pin).to contain_exactly(version_changes.to_a.last)
    end

    context "when the pin precedes every change" do
      let(:pin) { JsonApiKit::Timeline::FIRST_RELEASE }

      it "preserves the order of the changes" do
        expect(changes_after_pin.map { it.version.to_s }).to eq(%w[2026-09-01 2026-09-02])
      end
    end

    context "when the pin is the latest version" do
      let(:pin) { JsonApiKit::ApiVersion.parse("2026-09-02") }

      it "returns no change" do
        expect(changes_after_pin).to be_empty
      end
    end
  end
end
