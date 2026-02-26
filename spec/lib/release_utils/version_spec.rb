# frozen_string_literal: true

require "release_utils/version"

RSpec.describe ReleaseUtils::Version do
  describe ".new" do
    subject(:version) { described_class.new(version_string) }

    context "with a release version" do
      let(:version_string) { "2025.10.1" }

      it do
        is_expected.to have_attributes(major: 2025, minor: 10, patch: 1, pre: nil, revision: nil)
      end
    end

    context "with a development version" do
      let(:version_string) { "2025.10.0-latest" }

      it do
        is_expected.to have_attributes(
          major: 2025,
          minor: 10,
          patch: 0,
          pre: "latest",
          revision: nil,
        )
      end
    end

    context "with a development version with revision" do
      let(:version_string) { "2025.10.0-latest.3" }

      it do
        is_expected.to have_attributes(major: 2025, minor: 10, patch: 0, pre: "latest", revision: 3)
      end
    end

    context "with a malformed version string" do
      let(:version_string) { "not-a-version" }

      it { expect { version }.to raise_error(ArgumentError) }
    end

    it "freezes the instance" do
      expect(described_class.new("2025.10.0")).to be_frozen
    end
  end

  describe ".current" do
    subject(:version) { described_class.current }

    before { allow(File).to receive(:read).with("lib/version.rb").and_return(version_rb) }

    context "with a valid version file" do
      let(:version_rb) { "STRING = \"2025.10.0-latest\"" }
      let(:expected_version) { described_class.new("2025.10.0-latest") }

      it { is_expected.to eq expected_version }
    end

    context "with no version string" do
      let(:version_rb) { "no version here" }

      it { expect { version }.to raise_error(RuntimeError, /Unable to parse/) }
    end
  end

  describe ".next" do
    subject(:next_version) { described_class.next }

    before do
      allow(File).to receive(:read).with("lib/version.rb").and_return(
        "STRING = \"#{current_version}\"",
      )
    end

    context "when current version is older than the target month" do
      let(:current_version) { "2025.1.0-latest" }

      it "jumps to the current month" do
        freeze_time "2025-09-15" do
          expect(next_version).to eq("2025.9.0-latest")
        end
      end
    end

    context "when current version matches the target month" do
      let(:current_version) { "2025.10.0-latest" }

      it "increments to the next month" do
        freeze_time "2025-10-15" do
          expect(next_version).to eq("2025.11.0-latest")
        end
      end
    end

    context "when current version is ahead of the target month" do
      let(:current_version) { "2025.11.0-latest" }

      it "increments to the next month" do
        freeze_time "2025-10-15" do
          expect(next_version).to eq("2025.12.0-latest")
        end
      end
    end

    context "when current version has a revision" do
      let(:current_version) { "2025.10.0-latest.2" }

      it "increments to the next month without revision" do
        freeze_time "2025-10-15" do
          expect(next_version).to eq("2025.11.0-latest")
        end
      end
    end

    context "when incrementing past December" do
      let(:current_version) { "2025.12.0-latest" }

      it "rolls over to next year" do
        freeze_time "2025-12-15" do
          expect(next_version).to eq("2026.1.0-latest")
        end
      end
    end
  end

  describe "#to_s" do
    subject(:version_string) { described_class.new(input).to_s }

    context "with a release version" do
      let(:input) { "2025.10.1" }

      it { is_expected.to eq("2025.10.1") }
    end

    context "with a development version" do
      let(:input) { "2025.10.0-latest" }

      it { is_expected.to eq("2025.10.0-latest") }
    end

    context "with a development version with revision" do
      let(:input) { "2025.10.0-latest.2" }

      it { is_expected.to eq("2025.10.0-latest.2") }
    end
  end

  describe "#<=>" do
    subject(:version) { described_class.new(version_string) }

    context "with release versions" do
      let(:version_string) { "2025.10.1" }

      it { is_expected.to be > described_class.new("2025.10.0") }
      it { is_expected.to be < described_class.new("2025.11.0") }
      it { is_expected.to eq described_class.new("2025.10.1") }
    end

    context "with a development version" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to be < described_class.new("2025.10.0") }
    end

    context "with development version revisions" do
      let(:version_string) { "2025.10.0-latest.2" }

      it { is_expected.to be > described_class.new("2025.10.0-latest.1") }
      it { is_expected.to be > described_class.new("2025.10.0-latest") }
    end

    context "with a string argument" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.to be > "2025.9.0" }
    end

    context "with an incompatible type" do
      let(:version_string) { "2025.10.0" }

      it { expect(version <=> 42).to be_nil }
    end
  end

  describe "#development?" do
    subject(:version) { described_class.new(version_string) }

    context "with a development version" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to be_development }
    end

    context "with a development version with revision" do
      let(:version_string) { "2025.10.0-latest.1" }

      it { is_expected.to be_development }
    end

    context "with a release version" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.not_to be_development }
    end
  end

  describe "#same_development_cycle?" do
    subject(:version) { described_class.new(version_string) }

    RSpec::Matchers.alias_matcher :share_development_cycle_with, :be_same_development_cycle

    context "with two development versions in the same cycle" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to share_development_cycle_with(described_class.new("2025.10.0-latest")) }
    end

    context "with development versions differing only in revision" do
      let(:version_string) { "2025.10.0-latest.1" }

      it { is_expected.to share_development_cycle_with(described_class.new("2025.10.0-latest.2")) }
    end

    context "with development versions in different cycles" do
      let(:version_string) { "2025.10.0-latest" }

      it do
        is_expected.not_to share_development_cycle_with(described_class.new("2025.11.0-latest"))
      end
    end

    context "when one version is a release" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.not_to share_development_cycle_with(described_class.new("2025.10.0")) }
    end

    context "when both versions are releases" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.not_to share_development_cycle_with(described_class.new("2025.10.0")) }
    end
  end

  describe "#same_series?" do
    subject(:version) { described_class.new(version_string) }

    RSpec::Matchers.alias_matcher :share_series_with, :be_same_series

    context "with versions in the same series" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.to share_series_with(described_class.new("2025.10.1")) }
    end

    context "with a release and development version in the same series" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.to share_series_with(described_class.new("2025.10.0-latest")) }
    end

    context "with versions in different series" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.not_to share_series_with(described_class.new("2025.11.0")) }
    end
  end

  describe "#series" do
    subject(:series) { described_class.new(version_string).series }

    context "with a release version" do
      let(:version_string) { "2025.10.3" }

      it { is_expected.to eq("2025.10") }
    end

    context "with a development version with revision" do
      let(:version_string) { "2025.10.0-latest.2" }

      it { is_expected.to eq("2025.10") }
    end
  end

  describe "#branch_name" do
    subject(:branch_name) { described_class.new("2025.10.0-latest").branch_name }

    it { is_expected.to eq("release/2025.10") }
  end

  describe "#tag_name" do
    subject(:tag_name) { described_class.new(version_string).tag_name }

    context "with a release version" do
      let(:version_string) { "2025.10.0" }

      it { is_expected.to eq("v2025.10.0") }
    end

    context "with a development version" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to eq("v2025.10.0-latest") }
    end

    context "with a development version with revision" do
      let(:version_string) { "2025.10.0-latest.2" }

      it { is_expected.to eq("v2025.10.0-latest.2") }
    end
  end

  describe "#without_revision" do
    subject(:without_revision) { version.without_revision }

    context "with a development version with revision" do
      let(:version) { described_class.new("2025.10.0-latest.2") }

      it { is_expected.to eq("2025.10.0-latest") }
    end

    context "with a development version without revision" do
      let(:version) { described_class.new("2025.10.0-latest") }

      it { is_expected.to equal(version) }
    end

    context "with a release version" do
      let(:version) { described_class.new("2025.10.0") }

      it { is_expected.to equal(version) }
    end
  end

  describe "#next_development_cycle" do
    subject(:next_version) { described_class.new(version_string).next_development_cycle }

    context "with a standard development version" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to eq("2025.11.0-latest") }
    end

    context "with December (year rollover)" do
      let(:version_string) { "2025.12.0-latest" }

      it { is_expected.to eq("2026.1.0-latest") }
    end

    context "with a development version with revision" do
      let(:version_string) { "2025.10.0-latest.2" }

      it { is_expected.to eq("2025.11.0-latest") }
    end
  end

  describe "#next_revision" do
    subject(:next_version) { described_class.new(version_string).next_revision }

    context "with a plain development version" do
      let(:version_string) { "2025.10.0-latest" }

      it { is_expected.to eq("2025.10.0-latest.1") }
    end

    context "with an existing revision" do
      let(:version_string) { "2025.10.0-latest.2" }

      it { is_expected.to eq("2025.10.0-latest.3") }
    end
  end
end
