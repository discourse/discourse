# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Coverage::ReferenceCheck do
  subject(:check) { described_class.new(exempt_tables:) }

  # No exemptions unless a test opts in, so the existing cases keep asserting
  # the full schema against the reference converter.
  let(:exempt_tables) { [] }

  let(:schema_columns) { Migrations::Tooling::Coverage::SchemaColumns }
  let(:analyzer_class) { Migrations::Tooling::Coverage::ConverterAnalyzer }

  def model(name, required: [], optional: [])
    Migrations::Tooling::Coverage::SchemaColumns::Model.new(name:, required:, optional:)
  end

  def analysis(written: {}, unknown: {})
    Migrations::Tooling::Coverage::ConverterAnalyzer::Result.new(
      written_columns: written.transform_values { |columns| Set.new(columns) },
      unknown_models: unknown,
    )
  end

  # `results` maps converter name => analysis(...). The reference converter is
  # `discourse`, so include it unless a test is about its absence.
  #
  # `Migrations::Converters` lives in the converters gem, which isn't loaded in
  # the tooling gem's isolated specs, so a doubled constant stands in for it
  # (verified against the real module only where it happens to be loaded).
  #
  # `path_of` returns a path that differs from the converter name, and the
  # analyzer is keyed by that path, so a test proves `analyze` routes the
  # `path_of` result into the analyzer rather than the bare name.
  def stub_coverage(results, schema:)
    converters = class_double("Migrations::Converters").as_stubbed_const
    allow(converters).to receive(:names).and_return(results.keys)

    path_for = results.keys.to_h { |name| [name, "/converters/#{name}"] }
    name_for = path_for.invert
    allow(converters).to receive(:path_of) { |name| path_for.fetch(name) }

    allow(analyzer_class).to receive(:new) do |path|
      instance_double(analyzer_class, analyze: results.fetch(name_for.fetch(path)))
    end
    allow(schema_columns).to receive(:call).and_return(schema)
  end

  it "passes when the reference converter writes every column" do
    stub_coverage(
      { "discourse" => analysis(written: { "User" => %i[id name] }) },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[32m✓ The discourse converter covers all 2 IntermediateDB columns across 1 tables.\e[0m\n",
    ).to_stdout
    expect(passed).to be true
  end

  it "reports every missing column, sorted by table then column, with a total" do
    stub_coverage(
      # Reference writes only `id` for User and nothing for Category.
      { "discourse" => analysis(written: { "User" => [:id] }) },
      schema: {
        "User" => model("User", required: [:id], optional: %i[name email]),
        "Category" => model("Category", required: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[31m✗ The discourse converter does not write every IntermediateDB column.\e[0m\n" \
        "  Acknowledge each column in the converter (pass it explicitly, `column: nil` if the source has no value):\n" \
        "\n" \
        "  categories: id\n" \
        "  users: email, name\n" \
        "\n" \
        "\e[31m3 columns across 2 tables not covered.\e[0m\n",
    ).to_stdout
    expect(passed).to be false
  end

  it "uses singular wording when a single column in a single table is missing" do
    stub_coverage(
      { "discourse" => analysis(written: {}) },
      schema: {
        "Category" => model("Category", required: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[31m✗ The discourse converter does not write every IntermediateDB column.\e[0m\n" \
        "  Acknowledge each column in the converter (pass it explicitly, `column: nil` if the source has no value):\n" \
        "\n" \
        "  categories: id\n" \
        "\n" \
        "\e[31m1 column across 1 table not covered.\e[0m\n",
    ).to_stdout
    expect(passed).to be false
  end

  it "does not fail when a non-reference converter covers only a subset" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => %i[id name] }),
        "phpbb" => analysis(written: { "User" => [:id] }),
      },
      schema: {
        "User" => model("User", optional: %i[id name]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output.to_stdout
    expect(passed).to be true
  end

  # Only unknown columns, no unknown models: the models section must stay silent.
  it "fails and reports only the unknown columns when a converter writes an unknown column" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => [:id] }),
        "phpbb" => analysis(written: { "User" => %i[id bogus] }),
      },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[31m✗ The phpbb converter writes columns that don't exist in the IntermediateDB schema\e[0m\n" \
        "  (stale call sites after a schema change?):\n" \
        "\n" \
        "  users: bogus\n" \
        "\n",
    ).to_stdout
    expect(passed).to be false
  end

  # Only unknown models, no unknown columns: the columns section must stay silent.
  it "fails and reports only the unknown models when a converter writes an unknown model" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => [:id] }),
        "phpbb" => analysis(written: { "User" => [:id] }, unknown: { "Ghost" => ["steps/x.rb:1"] }),
      },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[31m✗ The phpbb converter writes to IntermediateDB models that don't exist:\e[0m\n" \
        "\n" \
        "  Ghost (steps/x.rb:1)\n" \
        "\n",
    ).to_stdout
    expect(passed).to be false
  end

  it "reports unknown columns (sorted) and unknown models (sorted) together" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => %i[id name], "Category" => [:id] }),
        "phpbb" =>
          analysis(
            written: {
              "User" => %i[id name zzz bogus],
              "Category" => %i[id x],
            },
            unknown: {
              "Ghost" => %w[steps/a.rb:1 steps/b.rb:2],
              "Abc" => ["s.rb:3"],
            },
          ),
      },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
        "Category" => model("Category", required: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[31m✗ The phpbb converter writes columns that don't exist in the IntermediateDB schema\e[0m\n" \
        "  (stale call sites after a schema change?):\n" \
        "\n" \
        "  categories: x\n" \
        "  users: bogus, zzz\n" \
        "\n" \
        "\e[31m✗ The phpbb converter writes to IntermediateDB models that don't exist:\e[0m\n" \
        "\n" \
        "  Abc (s.rb:3)\n" \
        "  Ghost (steps/a.rb:1, steps/b.rb:2)\n" \
        "\n",
    ).to_stdout
    expect(passed).to be false
  end

  it "ignores a written model the schema doesn't know when collecting unknown columns" do
    # `Ghost` is written but absent from the schema; the unknown-column pass must
    # skip it (unknown *models* are reported separately) instead of raising.
    stub_coverage(
      { "discourse" => analysis(written: { "User" => [:id], "Ghost" => [:x] }) },
      schema: {
        "User" => model("User", required: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(
      "\e[32m✓ The discourse converter covers all 1 IntermediateDB columns across 1 tables.\e[0m\n",
    ).to_stdout
    expect(passed).to be true
  end

  context "with an exempt table" do
    let(:exempt_tables) { ["PostQuote"] }

    it "passes when the reference converter is missing only an exempt table" do
      stub_coverage(
        { "discourse" => analysis(written: { "User" => %i[id name] }) },
        schema: {
          "User" => model("User", required: [:id], optional: [:name]),
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(
        "\e[32m✓ The discourse converter covers all 2 IntermediateDB columns across 1 tables.\e[0m\n" \
          "\n" \
          "\e[33m  1 table written by EmbedBuffer#write_for, held out of the per-converter check:\e[0m\n" \
          "\e[33m    post_quotes\e[0m\n",
      ).to_stdout
      expect(passed).to be true
    end

    it "lists every held-out table, sorted, with plural wording for more than one" do
      exempt_tables = %w[PostUpload PostQuote]
      check = described_class.new(exempt_tables:)

      stub_coverage(
        { "discourse" => analysis(written: { "User" => %i[id name], "PostQuote" => [:post_id] }) },
        schema: {
          "User" => model("User", required: [:id], optional: [:name]),
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
          "PostUpload" => model("PostUpload", required: [:post_id]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(
        "\e[32m✓ The discourse converter covers all 2 IntermediateDB columns across 1 tables.\e[0m\n" \
          "\n" \
          "\e[33m  2 tables written by EmbedBuffer#write_for, held out of the per-converter check:\e[0m\n" \
          "\e[33m    post_quotes\e[0m\n" \
          "\e[33m    post_uploads\e[0m\n",
      ).to_stdout
      expect(passed).to be true
    end

    it "still fails on a non-exempt missing column while a table is exempt" do
      stub_coverage(
        { "discourse" => analysis(written: { "User" => [:id] }) },
        schema: {
          "User" => model("User", required: [:id], optional: [:name]),
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(/does not write every/).to_stdout
      expect(passed).to be false
    end

    it "still rejects unknown columns written to an exempt table" do
      stub_coverage(
        { "discourse" => analysis(written: { "PostQuote" => %i[post_id placeholder bogus] }) },
        schema: {
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(/columns that don't exist/).to_stdout
      expect(passed).to be false
    end

    it "fails as stale when the reference already covers exempt tables in full" do
      exempt_tables = %w[PostUpload PostQuote]
      check = described_class.new(exempt_tables:)

      stub_coverage(
        {
          "discourse" =>
            analysis(
              written: {
                "PostQuote" => %i[post_id placeholder],
                "PostUpload" => [:post_id],
              },
            ),
        },
        schema: {
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
          "PostUpload" => model("PostUpload", required: [:post_id]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(
        "\e[31m✗ The discourse converter now covers tables held out by EMBED_BUFFER_TABLES.\e[0m\n" \
          "  Remove them — explicit create calls cover these now:\n" \
          "\n" \
          "  post_quotes\n" \
          "  post_uploads\n" \
          "\n",
      ).to_stdout
      expect(passed).to be false
    end

    it "fails as stale and sorts by table name, falling back to the model name off-schema" do
      # `Zebra` is gone from the schema (sorts by its model name), `PostQuote` is
      # covered in full (sorts by its table name `post_quotes`); the two order as
      # `Zebra` < `post_quotes`, which proves the sort key uses the fallback.
      exempt_tables = %w[Zebra PostQuote]
      check = described_class.new(exempt_tables:)

      stub_coverage(
        { "discourse" => analysis(written: { "PostQuote" => %i[post_id placeholder] }) },
        schema: {
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(
        "\e[31m✗ The discourse converter now covers tables held out by EMBED_BUFFER_TABLES.\e[0m\n" \
          "  Remove them — explicit create calls cover these now:\n" \
          "\n" \
          "  Zebra\n" \
          "  post_quotes\n" \
          "\n",
      ).to_stdout
      expect(passed).to be false
    end

    it "stays exempt when the reference covers an exempt table only partially" do
      stub_coverage(
        { "discourse" => analysis(written: { "PostQuote" => [:post_id] }) },
        schema: {
          "PostQuote" => model("PostQuote", required: %i[post_id placeholder]),
        },
      )

      passed = nil
      expect { passed = check.run }.to output(/covers all.*held out.*post_quotes/m).to_stdout
      expect(passed).to be true
    end
  end

  it "raises when the reference converter is not among the discovered converters" do
    stub_coverage(
      {
        "phpbb" => analysis(written: { "User" => [:id] }),
        "vanilla" => analysis(written: { "User" => [:id] }),
      },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    expect { check.run }.to raise_error(
      described_class::Error,
      "Reference converter 'discourse' was not found among the discovered converters: " \
        "phpbb, vanilla.\nThe coverage check cannot run without it.",
    )
  end

  it "defaults the exempt tables to the embed-buffer tables" do
    expect(described_class.new.instance_variable_get(:@exempt_tables)).to eq(
      described_class::EMBED_BUFFER_TABLES,
    )
  end

  it "runs a fresh instance and returns its result" do
    instance = instance_double(described_class, run: :the_result)
    allow(described_class).to receive(:new).and_return(instance)

    expect(described_class.run).to eq(:the_result)
    expect(instance).to have_received(:run)
  end
end
