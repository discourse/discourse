# frozen_string_literal: true

RSpec.describe SiteSettings::GroupRefs do
  describe ".resolve" do
    it "returns integers unchanged and parses numeric strings" do
      expect(described_class.resolve(0, context: "ctx")).to eq(0)
      expect(described_class.resolve(14, context: "ctx")).to eq(14)
      expect(described_class.resolve("0", context: "ctx")).to eq(0)
      expect(described_class.resolve("14", context: "ctx")).to eq(14)
      expect(described_class.resolve(" 14 ", context: "ctx")).to eq(14)
    end

    it "resolves automatic group names given as strings or symbols" do
      expect(described_class.resolve("admins", context: "ctx")).to eq(1)
      expect(described_class.resolve(:moderators, context: "ctx")).to eq(2)
      expect(described_class.resolve("anonymous_users", context: "ctx")).to eq(4)
      expect(described_class.resolve("logged_in_users", context: "ctx")).to eq(5)
      expect(described_class.resolve("trust_level_4", context: "ctx")).to eq(14)
    end

    it "raises a schema error naming the context and the offending token" do
      expect { described_class.resolve("zqxjkw", context: "some_setting default") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
        /some_setting default.*zqxjkw|zqxjkw.*some_setting default/m,
      )
    end

    it "suggests the closest automatic group name when one is near" do
      expect { described_class.resolve("admin", context: "ctx") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
        /admins/,
      )

      expect { described_class.resolve("trust_level4", context: "ctx") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
        /trust_level_4/,
      )
    end

    it "offers no name for the everyone pseudogroup, which is being retired" do
      expect { described_class.resolve("everyone", context: "ctx") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
        /everyone/,
      )
    end

    it "still resolves the everyone group id, because stored values contain it" do
      expect(described_class.resolve(0, context: "ctx")).to eq(0)
      expect(described_class.resolve("0", context: "ctx")).to eq(0)
    end

    it "rejects names that only differ by case" do
      expect { described_class.resolve("Admins", context: "ctx") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
      )
    end

    it "rejects blank and non-scalar references" do
      [nil, "", "   ", true, false, 1.5, [], {}].each do |ref|
        expect { described_class.resolve(ref, context: "ctx") }.to raise_error(
          SiteSettings::GroupRefs::SchemaError,
        ),
        "expected #{ref.inspect} to be rejected"
      end
    end
  end

  describe ".resolve_ids" do
    it "resolves pipe separated strings preserving order" do
      expect(described_class.resolve_ids("1|2|14", context: "ctx")).to eq([1, 2, 14])
      expect(described_class.resolve_ids("14|1", context: "ctx")).to eq([14, 1])
    end

    it "resolves names, mixed tokens and surrounding whitespace" do
      expect(described_class.resolve_ids("admins|moderators|trust_level_4", context: "ctx")).to eq(
        [1, 2, 14],
      )
      expect(described_class.resolve_ids(" admins | 2 |14", context: "ctx")).to eq([1, 2, 14])
    end

    it "resolves arrays, bare integers and drops blank tokens" do
      expect(described_class.resolve_ids(%w[admins 2 14], context: "ctx")).to eq([1, 2, 14])
      expect(described_class.resolve_ids(["admins", 2, "14"], context: "ctx")).to eq([1, 2, 14])
      expect(described_class.resolve_ids(14, context: "ctx")).to eq([14])
      expect(described_class.resolve_ids("1||2|", context: "ctx")).to eq([1, 2])
    end

    it "deduplicates while keeping the first occurrence" do
      expect(described_class.resolve_ids("2|1|2|admins", context: "ctx")).to eq([2, 1])
    end

    it "returns an empty array for blank input" do
      expect(described_class.resolve_ids(nil, context: "ctx")).to eq([])
      expect(described_class.resolve_ids("", context: "ctx")).to eq([])
      expect(described_class.resolve_ids([], context: "ctx")).to eq([])
    end

    it "raises a schema error when any token is unknown" do
      expect { described_class.resolve_ids("admins|adminz", context: "ctx") }.to raise_error(
        SiteSettings::GroupRefs::SchemaError,
        /adminz/,
      )
    end
  end

  describe ".resolve_list" do
    it "returns a canonical pipe separated string of ids" do
      expect(described_class.resolve_list("admins|trust_level_4", context: "ctx")).to eq("1|14")
      expect(described_class.resolve_list(%w[admins moderators], context: "ctx")).to eq("1|2")
      expect(described_class.resolve_list("1|2", context: "ctx")).to eq("1|2")
    end

    it "returns an empty string for blank input" do
      expect(described_class.resolve_list(nil, context: "ctx")).to eq("")
      expect(described_class.resolve_list("", context: "ctx")).to eq("")
    end
  end

  describe "database independence" do
    it "resolves references without touching the database" do # make sure the constant is already loaded
      queries =
        track_sql_queries do
          expect(described_class.resolve_list("admins|2|trust_level_4", context: "ctx")).to eq(
            "1|2|14",
          )
        end

      expect(queries).to eq([])
    end
  end
end
