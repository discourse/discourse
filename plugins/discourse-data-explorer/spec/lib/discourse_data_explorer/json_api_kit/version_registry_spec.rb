# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionRegistry do
  subject(:registry) { described_class.new(initial_version: "2026-05-01") }

  let(:today) { Date.parse("2026-07-08") }

  def change_class(version_date, description_text = "A change.")
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version version_date
      description description_text
    end
  end

  describe "#register" do
    context "when the change has no version" do
      let(:change) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) { description "..." }
      end

      it "rejects the change" do
        expect { registry.register(change) }.to raise_error(ArgumentError, /version/)
      end
    end

    context "when the change has no description" do
      let(:change) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) { version "2026-06-15" }
      end

      it "rejects the change" do
        expect { registry.register(change) }.to raise_error(ArgumentError, /description/)
      end
    end

    context "when the change predates the initial version" do
      it "rejects the change" do
        expect { registry.register(change_class("2026-04-01")) }.to raise_error(
          ArgumentError,
          /predates/,
        )
      end
    end
  end

  describe "#versions" do
    before do
      registry.register(change_class("2026-07-01"))
      registry.register(change_class("2026-06-15"))
    end

    it "includes the initial version and each change's version, sorted" do
      expect(registry.versions.map(&:to_s)).to eq(%w[2026-05-01 2026-06-15 2026-07-01])
    end

    it "exposes the newest version as the current one" do
      expect(registry.current_version.to_s).to eq("2026-07-01")
    end
  end

  describe "#resolve" do
    before { registry.register(change_class("2026-06-15")) }

    it "rejects nil" do
      expect { registry.resolve(nil, today:) }.to raise_error(described_class::MissingVersion)
    end

    it "rejects an empty string" do
      expect { registry.resolve("", today:) }.to raise_error(described_class::MissingVersion)
    end

    it "rejects a malformed value" do
      expect { registry.resolve("garbage", today:) }.to raise_error(
        DiscourseDataExplorer::JsonApiKit::ApiVersion::Invalid,
      )
    end

    it "rejects a date predating the first version" do
      expect { registry.resolve("2026-04-01", today:) }.to raise_error(
        described_class::UnknownVersion,
      )
    end

    it "rejects a future date" do
      expect { registry.resolve("2027-01-01", today:) }.to raise_error(
        described_class::FutureVersion,
      )
    end

    it "snaps a date between versions down to the previous version" do
      expect(registry.resolve("2026-05-20", today:).to_s).to eq("2026-05-01")
    end

    it "resolves an exact version date to itself" do
      expect(registry.resolve("2026-06-15", today:).to_s).to eq("2026-06-15")
    end

    it "snaps a date after the last version down to it" do
      expect(registry.resolve("2026-07-01", today:).to_s).to eq("2026-06-15")
    end
  end

  describe "#gap_for" do
    context "with changes on distinct dates" do
      let!(:older) { registry.register(change_class("2026-06-15")) }
      let!(:newer) { registry.register(change_class("2026-07-01")) }

      it "returns the changes newer than the given version, newest first" do
        expect(registry.gap_for(registry.initial_version)).to eq([newer, older])
      end

      it "excludes changes at or before the given version" do
        expect(registry.gap_for(older.version)).to eq([newer])
      end

      it "is empty at the current version" do
        expect(registry.gap_for(registry.current_version)).to be_empty
      end
    end

    context "with changes sharing a date" do
      let!(:first) { registry.register(change_class("2026-06-15", "First.")) }
      let!(:second) { registry.register(change_class("2026-06-15", "Second.")) }

      it "keeps registration order within the date" do
        expect(registry.gap_for(registry.initial_version)).to eq([second, first])
      end
    end
  end
end
