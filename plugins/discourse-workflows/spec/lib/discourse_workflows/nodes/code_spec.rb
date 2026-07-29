# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Code::V1 do
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({}) }
  let(:code_harness) do
    DiscourseWorkflows::CodeNodeExecutionHarness.new(node_class: described_class, sandbox: sandbox)
  end

  after { sandbox.dispose }

  describe "#execute" do
    it "defaults to runOnceForAllItems" do
      parameters = { "code" => "return $input.all();" }
      result =
        code_harness.execute(
          parameters: parameters,
          items: [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }],
        )

      expect(result.map { |item| item["json"]["n"] }).to eq([1, 2])
    end

    it "rejects legacy snake_case modes" do
      parameters = { "code" => "return { name: $json.name };", "mode" => "run_once_for_each_item" }
      expect { code_harness.execute(parameters: parameters) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Invalid Code mode/,
      )
    end

    it "rejects unsupported modes" do
      parameters = { "code" => "return $input.all();", "mode" => "run_sometimes" }
      expect { code_harness.execute(parameters: parameters) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Invalid Code mode/,
      )
    end

    it "executes JavaScript and returns the result" do
      result =
        code_harness.execute(
          code: 'return { greeting: "hello" };',
          items: [{ "json" => { "name" => "world" } }],
        )

      expect(result.first["json"]["greeting"]).to eq("hello")
    end

    it "exposes $json with the current item data" do
      result =
        code_harness.execute(
          code: "return { name: $json.name };",
          items: [{ "json" => { "name" => "Alice" } }],
        )

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "captures console.log output" do
      log = code_harness.execute_and_log(code: 'console.log("debug message"); return {};')

      expect(log.entries.size).to eq(1)
      expect(log.entries.first).to include("level" => "info", "message" => "debug message")
    end

    it "accumulates logs across all input items" do
      items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]
      log =
        code_harness.execute_and_log(
          code: 'console.log("item " + $json.n); return {};',
          items: items,
        )

      expect(log.entries.map { |e| e["message"] }).to eq(["item 1", "item 2"])
    end

    it "captures console.warn as warn level" do
      log = code_harness.execute_and_log(code: 'console.warn("careful"); return {};')

      expect(log.entries.first).to include("level" => "warn", "message" => "careful")
    end

    it "captures console.error as error level" do
      log = code_harness.execute_and_log(code: 'console.error("broken"); return {};')

      expect(log.entries.first).to include("level" => "error", "message" => "broken")
      expect(log.errors?).to be(true)
    end

    it "processes each input item independently" do
      items = [{ "json" => { "n" => 3 } }, { "json" => { "n" => 5 } }]
      result = code_harness.execute(code: "return { doubled: $json.n * 2 };", items: items)

      expect(result.map { |r| r["json"]["doubled"] }).to eq([6, 10])
    end

    it "raises when returning non-object values per item" do
      expect { code_harness.execute(code: 'return "just a string";') }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Code doesn't return an object/,
      )
    end

    it "raises when returning arrays per item" do
      expect { code_harness.execute(code: "return [{ json: { n: 1 } }];") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Code doesn't return a single object/,
      )
    end

    it "drops items when returning null per item" do
      items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]
      result =
        code_harness.execute(code: "return $json.n === 1 ? { kept: $json.n } : null;", items: items)

      expect(result.map { |item| item["json"]["kept"] }).to eq([1])
      expect(result.first["pairedItem"]).to eq("item" => 0)
    end

    it "preserves item-shaped return values" do
      result =
        code_harness.execute(
          code: "return { json: { name: $json.name }, pairedItem: 0 };",
          items: [{ "json" => { "name" => "Alice" } }],
        )

      expect(result.first).to eq("json" => { "name" => "Alice" }, "pairedItem" => { "item" => 0 })
    end

    it "allows returning the current input item" do
      result =
        code_harness.execute(
          code: "return $input.item;",
          items: [{ "json" => { "name" => "Alice" } }],
        )

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "rejects $input.all() in per-item mode" do
      expect {
        code_harness.execute(code: "return { count: $input.all().length };")
      }.to raise_error(DiscourseWorkflows::NodeError, /Can't use \.all\(\) here/)
    end

    it "keeps $json aliased to $input.item.json" do
      result = code_harness.execute(code: <<~JS)
          var sameRef = $json === $input.item.json;
          $input.item.json.foo = 1;
          $json.bar = 2;
          return { sameRef: sameRef, foo: $json.foo, bar: $input.item.json.bar };
        JS

      expect(result.first["json"]).to include("sameRef" => true, "foo" => 1, "bar" => 2)
    end

    it "allows returning $input without cloning function properties" do
      items = [{ "json" => { "name" => "Alice" } }]
      result = code_harness.execute(code: "return $input;", items: items)

      expect(result.first["json"]["item"]["json"]["name"]).to eq("Alice")
    end

    it "exposes the global item alias in per-item mode" do
      result =
        code_harness.execute(code: "return item;", items: [{ "json" => { "name" => "Alice" } }])

      expect(result.first["json"]["name"]).to eq("Alice")
    end

    it "exposes $input.params for the current code node" do
      parameters = {
        "code" => "return { mode: $input.params.mode };",
        "mode" => "runOnceForEachItem",
      }
      result = code_harness.execute(parameters: parameters)

      expect(result.first["json"]["mode"]).to eq("runOnceForEachItem")
    end

    it "exposes $itemIndex for each input item" do
      items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]
      result = code_harness.execute(code: "return { itemIndex: $itemIndex };", items: items)

      expect(result.map { |r| r["json"]["itemIndex"] }).to eq([0, 1])
    end

    it "raises when $input.all() exceeds the sandbox payload limit" do
      items = [
        { "json" => { "data" => "x" * DiscourseWorkflows::JsSandbox::MAX_INJECTED_JSON_BYTES } },
      ]

      expect {
        code_harness.execute(
          mode: "runOnceForAllItems",
          code: "return { count: $input.all().length };",
          items: items,
        )
      }.to raise_error(DiscourseWorkflows::JsSandbox::PayloadTooLargeError, /__allInputItems/)
    end

    it "raises when $().item exceeds the sandbox payload limit" do
      large_item = {
        "json" => {
          "data" => "x" * DiscourseWorkflows::JsSandbox::MAX_INJECTED_JSON_BYTES,
        },
      }

      expect {
        code_harness.execute(
          code: 'return $("Source").item;',
          resolver_context: {
            "$json" => {
            },
            "__current_node_id" => "code",
            "__input_sources" => [{ "node_name" => "Source", "output_index" => 0 }],
            "__node_runs" => {
              "Source" => [{ "outputs" => [[large_item]] }],
            },
          },
        )
      }.to raise_error(DiscourseWorkflows::JsSandbox::PayloadTooLargeError, /\$\(\)\.item/)
    end

    context "with workflow variables" do
      fab!(:api_key_variable) do
        Fabricate(:discourse_workflows_variable, key: "api_key", value: "secret123")
      end

      it "accesses workflow variables via $vars" do
        result = code_harness.execute(code: "return { key: $vars.api_key };")

        expect(result.first["json"]["key"]).to eq("secret123")
      end
    end

    it "filters secret site settings from $site_settings" do
      result =
        code_harness.execute(code: "return { val: $site_settings.discourse_connect_secret };")

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters hidden site settings from $site_settings" do
      result = code_harness.execute(code: "return { val: $site_settings.vapid_public_key };")

      expect(result.first["json"]["val"]).to eq("[FILTERED]")
    end

    it "filters internal context keys from $() node output accessor" do
      result = code_harness.execute(code: 'return $("__resume_token").item;')

      expect(result.first["json"]).to eq({})
    end

    it "exposes $execution variables" do
      result =
        code_harness.execute(
          code: "return { id: $execution.id, name: $execution.workflow_name };",
          resolver_context: {
            "$json" => {
            },
            "__execution" => {
              "id" => 99,
              "workflow_name" => "Test Flow",
            },
          },
        )

      expect(result.first["json"]["id"]).to eq(99)
      expect(result.first["json"]["name"]).to eq("Test Flow")
    end

    it "allows accessing normal node outputs via $()" do
      result =
        code_harness.execute(
          code: 'return $("MyNode").first().json;',
          resolver_context: {
            "$json" => {
            },
            "MyNode" => [{ "json" => { "data" => "visible" } }],
          },
        )

      expect(result.first["json"]["data"]).to eq("visible")
    end

    it "resolves $().item through pairedItem lineage" do
      result =
        code_harness.execute(
          code: 'return $("Split").item.json;',
          items: [{ "json" => { "id" => 2 } }],
          resolver_context: {
            "$json" => {
              "id" => 2,
            },
            "__current_node_id" => "code",
            "__input_sources" => [{ "node_name" => "Filter", "output_index" => 0 }],
            "Split" => [
              { "json" => { "id" => 1, "label" => "first" } },
              { "json" => { "id" => 2, "label" => "second" } },
            ],
            "__node_runs" => {
              "Split" => [
                {
                  "outputs" => [
                    [
                      { "json" => { "id" => 1, "label" => "first" } },
                      { "json" => { "id" => 2, "label" => "second" } },
                    ],
                  ],
                  "input_sources" => [{ "node_name" => "Source", "output_index" => 0 }],
                },
              ],
              "Filter" => [
                {
                  "outputs" => [[{ "json" => { "id" => 2 }, "pairedItem" => { "item" => 1 } }]],
                  "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
                },
              ],
            },
          },
        )

      expect(result.first["json"]["label"]).to eq("second")
    end

    it "raises when $().item cannot determine pairedItem lineage" do
      expect {
        code_harness.execute(
          code: 'return $("Split").item.json;',
          items: [{ "json" => { "id" => 2 } }],
          resolver_context: {
            "$json" => {
              "id" => 2,
            },
            "__current_node_id" => "code",
            "__input_sources" => [{ "node_name" => "Filter", "output_index" => 0 }],
            "Split" => [
              { "json" => { "label" => "first" } },
              { "json" => { "label" => "second" } },
            ],
            "__node_runs" => {
              "Split" => [
                {
                  "outputs" => [
                    [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
                  ],
                  "input_sources" => [{ "node_name" => "Source", "output_index" => 0 }],
                },
              ],
              "Filter" => [
                {
                  "outputs" => [[{ "json" => { "id" => 2 } }]],
                  "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
                },
              ],
            },
          },
        )
      }.to raise_error(
        DiscourseWorkflows::JsSandbox::SandboxError,
        /Info for expression missing from previous node/,
      )
    end

    it "raises on invalid JavaScript" do
      expect { code_harness.execute(code: "this is not valid js {{{") }.to raise_error(
        DiscourseWorkflows::JsSandbox::SandboxError,
      )
    end

    context "with mode runOnceForAllItems" do
      it "runs the code once and returns array results as items" do
        items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }, { "json" => { "n" => 3 } }]
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return $input.all().map(function(i) { return { doubled: i.json.n * 2 }; });",
            items: items,
          )

        expect(result.map { |r| r["json"]["doubled"] }).to eq([2, 4, 6])
      end

      it "exposes all-items input helpers" do
        items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code:
              "return { all: $input.all().length, first: $input.first().json.a, last: $input.last().json.b };",
            items: items,
          )

        expect(result.first["json"]).to include("all" => 2, "first" => 1, "last" => 2)
      end

      it "exposes the global items alias in all-items mode" do
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return { count: items.length };",
            items: [{ "json" => {} }, { "json" => {} }],
          )

        expect(result.first["json"]["count"]).to eq(2)
      end

      it "returns no items when code returns null" do
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return null;",
            items: [{ "json" => { "n" => 1 } }],
          )

        expect(result).to eq([])
      end

      it "raises when all-items code returns a primitive" do
        expect {
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return 1;",
            items: [{ "json" => {} }],
          )
        }.to raise_error(DiscourseWorkflows::NodeError, /Code doesn't return items properly/)
      end

      it "raises when an all-items array contains a primitive" do
        expect {
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return [1];",
            items: [{ "json" => {} }],
          )
        }.to raise_error(DiscourseWorkflows::NodeError, /Code doesn't return items properly/)
      end

      it "exposes node output data proxy helpers" do
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: <<~JS,
              return {
                count: $("Source").all().length,
                first: $("Source").first().json.id,
                last: $("Source").last().json.id,
                params: $("Source").params.mode,
                context: $("Source").context.done,
                executed: $("Source").isExecuted
              };
            JS
            items: [{ "json" => {} }],
            resolver_context: {
              "$json" => {
              },
              "__node_parameters_by_name" => {
                "Source" => {
                  "mode" => "manual",
                },
              },
              "__node_contexts" => {
                "Source" => {
                  "done" => true,
                },
              },
              "__node_runs" => {
                "Source" => [
                  { "outputs" => [[{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }]] },
                ],
              },
            },
          )

        expect(result.first["json"]).to include(
          "count" => 2,
          "first" => 1,
          "last" => 2,
          "params" => "manual",
          "context" => true,
          "executed" => true,
        )
      end

      it "defaults node output helpers to the connected source branch" do
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: 'return $("Source").first().json;',
            items: [{ "json" => {} }],
            resolver_context: {
              "$json" => {
              },
              "__current_node_id" => "code",
              "__input_sources" => [{ "node_name" => "Source", "output_index" => 1 }],
              "__node_runs" => {
                "Source" => [
                  {
                    "outputs" => [
                      [{ "json" => { "branch" => 0 } }],
                      [{ "json" => { "branch" => 1 } }],
                    ],
                  },
                ],
              },
            },
          )

        expect(result.first["json"]["branch"]).to eq(1)
      end

      it "wraps a single object return into one item" do
        items = [{ "json" => { "n" => 1 } }, { "json" => { "n" => 2 } }]
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code:
              "var sum = $input.all().reduce(function(s, i) { return s + i.json.n; }, 0); return { total: sum };",
            items: items,
          )

        expect(result.length).to eq(1)
        expect(result.first["json"]["total"]).to eq(3)
      end

      it "binds $json to the first item in all-items mode" do
        items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]
        result =
          code_harness.execute(
            mode: "runOnceForAllItems",
            code: "return { keys: Object.keys($json) };",
            items: items,
          )

        expect(result.length).to eq(1)
        expect(result.first["json"]["keys"]).to eq(["a"])
      end
    end
  end
end
