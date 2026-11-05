# frozen_string_literal: true

RSpec.describe SiteSettings::GroupListConstraints do
  # Compiles `opts` the way the settings pipeline does and returns
  # `[constraints, errors]`. `opts` is mutated, exactly as in production.
  def compile(opts, name: :test_setting, group_type: true, lenient: false)
    described_class.from_opts!(opts, name: name, group_type: group_type, lenient: lenient)
  end

  # Compiles `opts` and asserts that it produced no schema error.
  def constraints_for(opts, **kwargs)
    constraints, errors = compile(opts, **kwargs)
    expect(errors).to eq([])
    constraints
  end

  describe ".from_opts! with a group list" do
    it "returns an empty constraints object when no rule is declared" do
      opts = { type: "group_list" }
      constraints = constraints_for(opts)

      expect(constraints).not_to be_nil
      expect(constraints.at_least_one).to eq(false)
      expect(constraints.at_least_one_message).to be_nil
      expect(constraints.mandatory_ids).to eq([])
      expect(constraints.disallowed_ids).to eq([])
      expect(constraints.mandatory_values).to be_nil
      expect(constraints.disallowed_groups).to be_nil
      expect(constraints).not_to be_strict
    end

    it "compiles the constraints block and consumes it from opts" do
      opts = {
        type: "group_list",
        constraints: {
          at_least_one: true,
          mandatory: %w[admins moderators],
          disallowed: %w[anonymous_users],
        },
      }
      constraints = constraints_for(opts)

      expect(constraints.at_least_one).to eq(true)
      expect(constraints.at_least_one_message).to be_nil
      expect(constraints.mandatory_ids).to eq([1, 2])
      expect(constraints.disallowed_ids).to eq([4])
      expect(constraints).to be_strict
      expect(opts).to eq({ type: "group_list" })
    end

    it "accepts ids, strings and symbols in the rule arrays" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              mandatory: [1, "moderators"],
              disallowed: [:anonymous_users],
            },
          },
        )

      expect(constraints.mandatory_ids).to eq([1, 2])
      expect(constraints.disallowed_ids).to eq([4])
    end

    it "accepts a custom message for at_least_one" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              at_least_one: {
                message: "site_settings.errors.invalid_group",
              },
            },
          },
        )

      expect(constraints.at_least_one).to eq(true)
      expect(constraints.at_least_one_message).to eq("site_settings.errors.invalid_group")
    end

    it "treats at_least_one: false as no rule" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: false } })

      expect(constraints.at_least_one).to eq(false)
    end

    it "is frozen, along with its id arrays" do
      constraints = constraints_for({ type: "group_list", constraints: { mandatory: %w[admins] } })

      expect(constraints).to be_frozen
      expect(constraints.mandatory_ids).to be_frozen
      expect(constraints.disallowed_ids).to be_frozen
    end
  end

  describe ".from_opts! with legacy keys" do
    it "compiles mandatory_values, disallowed_groups and the at-least-one validator" do
      opts = {
        type: "group_list",
        mandatory_values: "1|2",
        disallowed_groups: "4",
        validator: "AtLeastOneGroupValidator",
      }
      constraints = constraints_for(opts)

      expect(constraints.at_least_one).to eq(true)
      expect(constraints.mandatory_ids).to eq([1, 2])
      expect(constraints.disallowed_ids).to eq([4])
      expect(constraints).not_to be_strict
      expect(opts).to eq({ type: "group_list" })
    end

    it "produces the same object as the equivalent constraints block" do
      legacy =
        constraints_for(
          {
            type: "group_list",
            mandatory_values: "1|2",
            disallowed_groups: "4",
            validator: "AtLeastOneGroupValidator",
          },
        )
      declared =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              at_least_one: true,
              mandatory: %w[admins moderators],
              disallowed: %w[anonymous_users],
            },
          },
        )

      expect(legacy).to eq(declared)
    end

    it "leaves any other validator in opts" do
      opts = { type: "group_list", validator: "Chat::DirectMessageEnabledGroupsValidator" }
      constraints = constraints_for(opts)

      expect(constraints.at_least_one).to eq(false)
      expect(opts[:validator]).to eq("Chat::DirectMessageEnabledGroupsValidator")
    end

    it "resolves symbolic names in legacy values" do
      constraints =
        constraints_for(
          { type: "group_list", mandatory_values: "admins", disallowed_groups: "anonymous_users" },
        )

      expect(constraints.mandatory_ids).to eq([1])
      expect(constraints.disallowed_ids).to eq([4])
    end
  end

  describe ".from_opts! with a non group type" do
    it "returns nil and leaves mandatory_values untouched" do
      opts = { type: "list", mandatory_values: "discourse|admin" }
      constraints, errors = compile(opts, name: :reserved_usernames, group_type: false)

      expect(constraints).to be_nil
      expect(errors).to eq([])
      expect(opts).to eq({ type: "list", mandatory_values: "discourse|admin" })
    end

    it "reports an error when constraints are declared" do
      _, errors = compile({ type: "list", constraints: { at_least_one: true } }, group_type: false)

      expect(errors.size).to eq(1)
      expect(errors.first).to include("constraints")
    end

    it "reports an error when disallowed_groups is declared" do
      _, errors = compile({ type: "list", disallowed_groups: "4" }, group_type: false)

      expect(errors.size).to eq(1)
      expect(errors.first).to include("disallowed_groups")
    end
  end

  describe ".from_opts! schema errors" do
    it "reports an unknown key with the closest suggestion" do
      _, errors = compile({ type: "group_list", constraints: { at_leastone: true } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("at_leastone")
      expect(errors.first).to include("at_least_one")
      expect(errors.first).to include("test_setting")
    end

    it "reports a constraints block that is not a map" do
      _, errors = compile({ type: "group_list", constraints: "at_least_one" })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("constraints")
      expect(errors.first).to include("test_setting")
    end

    it "reports mandatory that is not a YAML array" do
      _, errors = compile({ type: "group_list", constraints: { mandatory: "1|2" } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("mandatory")
    end

    it "reports a rule key that was written with no value" do
      _, errors = compile({ type: "group_list", constraints: { mandatory: nil } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("mandatory")
    end

    it "reports disallowed that is not a YAML array" do
      _, errors = compile({ type: "group_list", constraints: { disallowed: { a: 1 } } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("disallowed")
    end

    it "reports an at_least_one value that is neither a boolean nor a message hash" do
      _, errors = compile({ type: "group_list", constraints: { at_least_one: "yes" } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("at_least_one")
    end

    it "reports a non string at_least_one message" do
      _, errors = compile({ type: "group_list", constraints: { at_least_one: { message: 5 } } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("message")
    end

    it "reports an unknown key inside the at_least_one hash" do
      _, errors = compile({ type: "group_list", constraints: { at_least_one: { mesage: "x" } } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("mesage")
    end

    it "reports an unknown group name and names the rule it came from" do
      _, errors = compile({ type: "group_list", constraints: { mandatory: %w[adminz] } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("adminz")
      expect(errors.first).to include("admins")
      expect(errors.first).to include("mandatory")
    end

    it "reports a group listed as both mandatory and disallowed" do
      _, errors =
        compile(
          {
            type: "group_list",
            constraints: {
              mandatory: %w[admins moderators],
              disallowed: %w[moderators],
            },
          },
        )

      expect(errors.size).to eq(1)
      expect(errors.first).to include("moderators")
    end

    it "reports a constraints block mixed with a legacy key" do
      _, errors =
        compile({ type: "group_list", mandatory_values: "1", constraints: { at_least_one: true } })

      expect(errors.size).to eq(1)
      expect(errors.first).to include("constraints")
      expect(errors.first).to include("mandatory_values")
    end
  end

  describe ".from_opts! lenient degradation" do
    it "discards the whole constraints block but keeps legacy keys" do
      opts = {
        type: "group_list",
        mandatory_values: "1|2",
        constraints: {
          at_least_one: true,
          disallowed: %w[anonymous_users],
        },
      }
      constraints, errors = compile(opts, lenient: true)

      expect(errors.size).to eq(1)
      expect(constraints.at_least_one).to eq(false)
      expect(constraints.mandatory_ids).to eq([1, 2])
      expect(constraints.disallowed_ids).to eq([])
      expect(opts).to eq({ type: "group_list" })
    end

    it "drops every rule of a block that has a single bad entry" do
      constraints, errors =
        compile(
          {
            type: "group_list",
            constraints: {
              at_least_one: true,
              mandatory: %w[admins],
              disallowed: %w[adminz],
            },
          },
          lenient: true,
        )

      expect(errors.size).to eq(1)
      expect(constraints.at_least_one).to eq(false)
      expect(constraints.mandatory_ids).to eq([])
      expect(constraints.disallowed_ids).to eq([])
    end

    it "drops legacy rules that fail to compile" do
      constraints, errors =
        compile({ type: "group_list", disallowed_groups: "adminz" }, lenient: true)

      expect(errors.size).to eq(1)
      expect(constraints.disallowed_ids).to eq([])
    end
  end

  describe "#normalize_ids" do
    let(:constraints) do
      constraints_for(
        {
          type: "group_list",
          constraints: {
            mandatory: %w[admins moderators],
            disallowed: %w[anonymous_users],
          },
        },
      )
    end

    it "puts mandatory ids first, strips disallowed ids and deduplicates" do
      expect(constraints.normalize_ids([14, 4, 1])).to eq([1, 2, 14])
      expect(constraints.normalize_ids([])).to eq([1, 2])
      expect(constraints.normalize_ids([4])).to eq([1, 2])
    end

    it "returns integers" do
      expect(constraints.normalize_ids([14]).map(&:class).uniq).to eq([Integer])
    end

    it "leaves the argument untouched" do
      ids = [14, 4]
      constraints.normalize_ids(ids)

      expect(ids).to eq([14, 4])
    end
  end

  describe "#normalize" do
    let(:constraints) do
      constraints_for(
        {
          type: "group_list",
          constraints: {
            mandatory: %w[admins moderators],
            disallowed: %w[anonymous_users],
          },
        },
      )
    end

    it "returns a pipe separated string with mandatory ids first" do
      expect(constraints.normalize("14|4")).to eq("1|2|14")
      expect(constraints.normalize("14")).to eq("1|2|14")
      expect(constraints.normalize(14)).to eq("1|2|14")
      expect(constraints.normalize([14, "4"])).to eq("1|2|14")
    end

    it "returns the mandatory ids for blank input" do
      expect(constraints.normalize(nil)).to eq("1|2")
      expect(constraints.normalize("")).to eq("1|2")
    end

    it "returns an empty string when there is nothing to keep" do
      unconstrained = constraints_for({ type: "group_list" })

      expect(unconstrained.normalize(nil)).to eq("")
      expect(unconstrained.normalize("")).to eq("")
      expect(unconstrained.normalize("14|4")).to eq("14|4")
    end

    it "drops tokens that are not integers instead of raising" do
      expect(constraints.normalize("admins|14")).to eq("1|2|14")
      expect(constraints.normalize("true")).to eq("1|2")
    end
  end

  describe "#normalize!" do
    let(:constraints) do
      constraints_for({ type: "group_list", constraints: { mandatory: %w[admins] } })
    end

    it "normalizes integer tokens like #normalize" do
      expect(constraints.normalize!("14", name: :test_setting)).to eq("1|14")
      expect(constraints.normalize!(nil, name: :test_setting)).to eq("1")
    end

    it "rejects a token that is not an integer" do
      expect { constraints.normalize!("admins", name: :test_setting) }.to raise_error(
        Discourse::InvalidParameters,
        /admins/,
      )
    end

    it "rejects a bad token mixed in with good ones" do
      expect { constraints.normalize!("14|nope", name: :test_setting) }.to raise_error(
        Discourse::InvalidParameters,
        /nope/,
      )
    end

    it "names every bad token, not just the first" do
      expect { constraints.normalize!("nope|14|nah", name: :test_setting) }.to raise_error(
        Discourse::InvalidParameters,
        /nope.*nah/m,
      )
    end

    it "reports the rejected tokens through a translated message" do
      expect { constraints.normalize!("admins|nope", name: :test_setting) }.to raise_error(
        Discourse::InvalidParameters,
        "test_setting: #{I18n.t("site_settings.errors.invalid_group_ids", ids: "admins, nope")}",
      )
    end
  end

  describe "#errors_for" do
    fab!(:group)

    it "returns no error when at_least_one is not declared and the value is blank" do
      constraints = constraints_for({ type: "group_list" })

      expect(constraints.errors_for("")).to eq([])
    end

    it "returns the default at-least-one message for a blank value" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })
      message = I18n.t("site_settings.errors.at_least_one_group_required")

      expect(constraints.errors_for("")).to eq([message])
      expect(constraints.errors_for(nil)).to eq([message])
      expect(constraints.errors_for("1")).to eq([])
    end

    it "uses the custom at-least-one message when one is declared" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              at_least_one: {
                message: "site_settings.errors.invalid_group",
              },
            },
          },
        )

      expect(constraints.errors_for("")).to eq([I18n.t("site_settings.errors.invalid_group")])
    end

    it "reports group ids that do not exist when at_least_one is declared" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect(constraints.errors_for("#{group.id}|123456789")).to eq(
        [I18n.t("site_settings.errors.unknown_group_ids", ids: "123456789")],
      )
    end

    # `AtLeastOneGroupValidator` rejected both a blank value and a nonexistent id,
    # and it guarded only the settings that declared it. A setting that never had
    # it keeps accepting a stale id, so a read-modify-write of a value holding one
    # cannot start failing.
    it "leaves nonexistent ids alone when no rule is declared" do
      constraints = constraints_for({ type: "group_list" })

      expect(constraints.errors_for("#{group.id}|123456789")).to eq([])
    end

    it "accepts ids of existing groups" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect(constraints.errors_for(group.id.to_s)).to eq([])
    end

    it "does not query the database for automatic group ids" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })
      queries = track_sql_queries { expect(constraints.errors_for("0|1|2|3|4|5|14")).to eq([]) }

      expect(queries).to eq([])
    end

    it "issues a single query for several non automatic ids" do
      other = Fabricate(:group)
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })
      # `fab!` refinds its record on first access, so the ids have to be read
      # before the queries are tracked.
      value = "1|#{group.id}|#{other.id}"
      queries = track_sql_queries { expect(constraints.errors_for(value)).to eq([]) }

      expect(queries.size).to eq(1)
    end

    it "skips the existence check when the database is unavailable" do
      GlobalSetting.stubs(:skip_db?).returns(true)
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect(constraints.errors_for("123456789")).to eq([])
    end
  end

  describe "#validate!" do
    it "does nothing when the value satisfies the rules" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect { constraints.validate!("1", name: :test_setting) }.not_to raise_error
    end

    it "raises with the setting name and the joined error messages" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect { constraints.validate!("", name: :test_setting) }.to raise_error(
        Discourse::InvalidParameters,
        "test_setting: #{I18n.t("site_settings.errors.at_least_one_group_required")}",
      )
    end
  end

  describe "#validate_default!" do
    it "returns the normalized default when it satisfies a declared block" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              mandatory: %w[admins moderators],
              disallowed: %w[anonymous_users],
            },
          },
        )

      expect(constraints.validate_default!("1|2|14", name: :test_setting)).to eq("1|2|14")
    end

    it "raises when a declared default is missing a mandatory group" do
      constraints =
        constraints_for({ type: "group_list", constraints: { mandatory: %w[admins moderators] } })

      expect { constraints.validate_default!("14", name: :test_setting) }.to raise_error(
        SiteSettings::GroupListConstraints::SchemaError,
        /test_setting/,
      )
    end

    it "raises when a declared default contains a disallowed group" do
      constraints =
        constraints_for({ type: "group_list", constraints: { disallowed: %w[anonymous_users] } })

      expect { constraints.validate_default!("1|4", name: :test_setting) }.to raise_error(
        SiteSettings::GroupListConstraints::SchemaError,
        /test_setting/,
      )
    end

    it "raises when a declared default is empty but at_least_one is required" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect { constraints.validate_default!("", name: :test_setting) }.to raise_error(
        SiteSettings::GroupListConstraints::SchemaError,
        /test_setting/,
      )
    end

    it "silently normalizes a legacy default instead of raising" do
      constraints =
        constraints_for({ type: "group_list", mandatory_values: "1|2", disallowed_groups: "4" })

      expect(constraints.validate_default!("14|4", name: :test_setting)).to eq("1|2|14")
      expect(constraints.validate_default!("", name: :test_setting)).to eq("1|2")
    end
  end

  describe "#mandatory_values and #disallowed_groups" do
    it "derives the wire strings in declaration order" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              mandatory: [0, :anonymous_users, :logged_in_users],
              disallowed: %w[trust_level_4 admins],
            },
          },
        )

      expect(constraints.mandatory_values).to eq("0|4|5")
      expect(constraints.disallowed_groups).to eq("14|1")
    end

    it "returns nil when the rule is not declared" do
      constraints = constraints_for({ type: "group_list", constraints: { at_least_one: true } })

      expect(constraints.mandatory_values).to be_nil
      expect(constraints.disallowed_groups).to be_nil
    end
  end

  describe "cache safety" do
    it "survives a Marshal round trip so it can travel through DistributedCache" do
      constraints =
        constraints_for(
          {
            type: "group_list",
            constraints: {
              at_least_one: {
                message: "site_settings.errors.invalid_group",
              },
              mandatory: %w[admins],
              disallowed: %w[anonymous_users],
            },
          },
        )
      restored = Marshal.load(Marshal.dump(constraints))

      expect(restored).to eq(constraints)
      expect(restored).to be_frozen
      expect(restored.mandatory_ids).to be_frozen
      expect(restored.mandatory_values).to eq("1")
      expect(restored.mandatory_ids).to eq([1])
      expect(restored.disallowed_ids).to eq([4])
      expect(restored.at_least_one_message).to eq("site_settings.errors.invalid_group")
    end
  end
end
