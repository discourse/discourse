# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Sort::V1 do
  def execute(input_items, configuration = {})
    config = { "type" => "simple" }.merge(configuration)
    execute_node_output(configuration: config, input_items: input_items).first
  end

  def sort_fields(*fields)
    { "values" => fields }
  end

  describe "simple mode" do
    it "sorts items ascending by a single field" do
      input = [
        { "json" => { "name" => "Charlie" } },
        { "json" => { "name" => "Alice" } },
        { "json" => { "name" => "Bob" } },
      ]
      result =
        execute(
          input,
          "sort_fields" => sort_fields({ "field_name" => "name", "order" => "ascending" }),
        )

      expect(result.map { |i| i["json"]["name"] }).to eq(%w[Alice Bob Charlie])
    end

    it "sorts items descending by a single field" do
      input = [
        { "json" => { "score" => 10 } },
        { "json" => { "score" => 30 } },
        { "json" => { "score" => 20 } },
      ]
      result =
        execute(
          input,
          "sort_fields" => sort_fields({ "field_name" => "score", "order" => "descending" }),
        )

      expect(result.map { |i| i["json"]["score"] }).to eq([30, 20, 10])
    end

    it "is case-insensitive for string comparisons" do
      input = [
        { "json" => { "name" => "banana" } },
        { "json" => { "name" => "Apple" } },
        { "json" => { "name" => "cherry" } },
      ]
      result =
        execute(
          input,
          "sort_fields" => sort_fields({ "field_name" => "name", "order" => "ascending" }),
        )

      expect(result.map { |i| i["json"]["name"] }).to eq(%w[Apple banana cherry])
    end

    it "places nil values first" do
      input = [
        { "json" => { "name" => "Bob" } },
        { "json" => { "other" => "no name field" } },
        { "json" => { "name" => "Alice" } },
      ]
      result =
        execute(
          input,
          "sort_fields" => sort_fields({ "field_name" => "name", "order" => "ascending" }),
        )

      expect(result[0]["json"]).not_to have_key("name")
      expect(result[1]["json"]["name"]).to eq("Alice")
      expect(result[2]["json"]["name"]).to eq("Bob")
    end

    it "sorts by multiple fields with priority order" do
      input = [
        { "json" => { "dept" => "Sales", "name" => "Charlie" } },
        { "json" => { "dept" => "Engineering", "name" => "Bob" } },
        { "json" => { "dept" => "Sales", "name" => "Alice" } },
        { "json" => { "dept" => "Engineering", "name" => "Alice" } },
      ]
      result =
        execute(
          input,
          "sort_fields" =>
            sort_fields(
              { "field_name" => "dept", "order" => "ascending" },
              { "field_name" => "name", "order" => "ascending" },
            ),
        )

      expect(result.map { |i| [i["json"]["dept"], i["json"]["name"]] }).to eq(
        [%w[Engineering Alice], %w[Engineering Bob], %w[Sales Alice], %w[Sales Charlie]],
      )
    end

    it "supports dot notation for nested fields" do
      input = [
        { "json" => { "address" => { "city" => "New York" } } },
        { "json" => { "address" => { "city" => "Boston" } } },
        { "json" => { "address" => { "city" => "Chicago" } } },
      ]
      result =
        execute(
          input,
          "sort_fields" => sort_fields({ "field_name" => "address.city", "order" => "ascending" }),
        )

      expect(result.map { |i| i["json"]["address"]["city"] }).to eq(%w[Boston Chicago New\ York])
    end

    it "returns items unchanged when sort_fields is empty" do
      input = [{ "json" => { "a" => 2 } }, { "json" => { "a" => 1 } }]
      result = execute(input, "sort_fields" => sort_fields)

      expect(result.map { |i| i["json"]["a"] }).to eq([2, 1])
    end
  end

  describe "random mode" do
    it "returns all items in a shuffled order" do
      input = (1..20).map { |i| { "json" => { "n" => i } } }
      result = execute(input, "type" => "random")

      expect(result.map { |i| i["json"]["n"] }).to contain_exactly(*(1..20))
    end
  end

  describe "code mode" do
    it "sorts items using a custom JavaScript comparator" do
      input = [{ "json" => { "n" => 3 } }, { "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]
      result = execute(input, "type" => "code", "code" => "return a.json.n - b.json.n;")

      expect(result.map { |i| i["json"]["n"] }).to eq([1, 2, 3])
    end

    it "supports descending sort via custom comparator" do
      input = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 3 } }, { "json" => { "n" => 2 } }]
      result = execute(input, "type" => "code", "code" => "return b.json.n - a.json.n;")

      expect(result.map { |i| i["json"]["n"] }).to eq([3, 2, 1])
    end

    it "raises when code is missing a return statement" do
      input = [{ "json" => { "n" => 1 } }]

      expect { execute(input, "type" => "code", "code" => "a.json.n - b.json.n;") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /return/,
      )
    end

    it "raises on invalid JavaScript" do
      input = [{ "json" => { "n" => 1 } }]

      expect { execute(input, "type" => "code", "code" => "return {{{invalid;") }.to raise_error(
        DiscourseWorkflows::JsSandbox::SandboxError,
      )
    end

    it "raises node errors for task runner failures without exception objects" do
      job_result =
        DiscourseWorkflows::Executor::NodeExecutionContext::JobResult.new(
          ok: false,
          result: nil,
          error: "broken",
        )
      parameters = { "type" => "code", "code" => "return 0;" }
      exec_ctx =
        double(
          input_items: [{ "json" => { "n" => 1 } }],
          get_mode: "manual",
          continue_on_fail: false,
          get_node: double(parameters: parameters),
          start_job: job_result,
        )
      allow(exec_ctx).to receive(:get_node_parameter) { |key, _item_index| parameters[key] }

      expect { described_class.new.execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "JavaScript execution failed: broken",
      )
    end

    it "captures console.log output" do
      input = [{ "json" => { "n" => 2 } }, { "json" => { "n" => 1 } }]
      configuration = {
        "type" => "code",
        "code" => 'console.log("comparing", a.json.n, b.json.n); return a.json.n - b.json.n;',
      }
      execute_node_output(configuration: configuration, input_items: input) do |ctx|
        messages = ctx.log.entries.map { |e| e["message"] }
        expect(messages).to include(a_string_matching(/comparing/))
      end
    end
  end
end
