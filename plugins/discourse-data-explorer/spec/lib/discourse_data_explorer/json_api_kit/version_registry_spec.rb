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
    it "rejects a change without a version" do
      change = Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) { description "..." }

      expect { registry.register(change) }.to raise_error(ArgumentError, /version/)
    end

    it "rejects a change without a description" do
      change = Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) { version "2026-06-15" }

      expect { registry.register(change) }.to raise_error(ArgumentError, /description/)
    end

    it "rejects a change predating the initial version" do
      expect { registry.register(change_class("2026-04-01")) }.to raise_error(
        ArgumentError,
        /predates/,
      )
    end
  end

  describe "#versions" do
    it "includes the initial version and each change's version, sorted" do
      registry.register(change_class("2026-07-01"))
      registry.register(change_class("2026-06-15"))

      expect(registry.versions.map(&:to_s)).to eq(%w[2026-05-01 2026-06-15 2026-07-01])
      expect(registry.current_version.to_s).to eq("2026-07-01")
    end
  end

  describe "#resolve" do
    before { registry.register(change_class("2026-06-15")) }

    it "rejects a blank value" do
      expect { registry.resolve(nil, today:) }.to raise_error(described_class::MissingVersion)
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
    it "returns the changes newer than the given version, newest first" do
      older = registry.register(change_class("2026-06-15"))
      newer = registry.register(change_class("2026-07-01"))

      expect(registry.gap_for(registry.initial_version)).to eq([newer, older])
      expect(registry.gap_for(older.version)).to eq([newer])
      expect(registry.gap_for(registry.current_version)).to be_empty
    end

    it "keeps registration order for changes sharing a date" do
      first = registry.register(change_class("2026-06-15", "First."))
      second = registry.register(change_class("2026-06-15", "Second."))

      expect(registry.gap_for(registry.initial_version)).to eq([second, first])
    end
  end
end
