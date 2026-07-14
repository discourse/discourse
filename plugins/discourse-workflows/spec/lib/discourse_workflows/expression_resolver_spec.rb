# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionResolver do
  subject(:resolver) { build_resolver(context.merge("$json" => context["$trigger"])) }

  fab!(:api_url_variable) do
    Fabricate(:discourse_workflows_variable, key: "API_URL", value: "https://example.com")
  end
  fab!(:prefix_variable) { Fabricate(:discourse_workflows_variable, key: "PREFIX", value: "hello") }

  let(:context) { { "$trigger" => { "topic_id" => 42, "tags" => %w[bug help] } } }

  before do
    @resolvers_under_test = []
    @sandboxes_under_test = []
  end

  after do
    @resolvers_under_test.each(&:dispose)
    @sandboxes_under_test.each(&:dispose)
  end

  def build_resolver(ctx, **kwargs)
    sandbox = DiscourseWorkflows::JsSandbox.new(ctx)
    @sandboxes_under_test << sandbox
    resolver = described_class.new(ctx, sandbox: sandbox, **kwargs)
    @resolvers_under_test << resolver
    resolver
  end

  describe "#resolve" do
    it "returns non-string values as-is" do
      expect(resolver.resolve(42)).to eq(42)
      expect(resolver.resolve(true)).to be(true)
      expect(resolver.resolve(nil)).to be_nil
    end

    it "returns fixed strings as-is" do
      expect(resolver.resolve("hello")).to eq("hello")
    end

    it "resolves context dot-path expressions preserving type" do
      expect(resolver.resolve("={{ $trigger.topic_id }}")).to eq(42)
    end

    it "resolves $json expressions preserving type" do
      expect(resolver.resolve("={{ $json.topic_id }}")).to eq(42)
    end

    it "exposes $input.item as the current input item" do
      expect(resolver.resolve("={{ $input.item.json.topic_id }}")).to eq(42)
    end

    it "allows resolving $input without cloning function properties" do
      result = resolver.resolve("={{ $input }}")

      expect(result["item"]["json"]["topic_id"]).to eq(42)
    end

    it "resolves $site_settings expressions" do
      SiteSetting.title = "My Forum"
      expect(resolver.resolve("={{ $site_settings.title }}")).to eq("My Forum")
    end

    it "handles mixed literal and expression" do
      expect(resolver.resolve("=topic-{{ $trigger.topic_id }}-closed")).to eq("topic-42-closed")
    end

    it "handles multiple expressions" do
      expect(resolver.resolve("={{ $trigger.topic_id }}-{{ $json.topic_id }}")).to eq("42-42")
    end

    it "resolves node output references preserving type" do
      node_context = {
        "Previous Step" => [{ "json" => { "topic_id" => 99, "tags" => %w[dev ops] } }],
      }

      node_resolver = build_resolver(node_context.merge("$json" => context["$trigger"]))

      expect(node_resolver.resolve("={{ $('Previous Step').first().json.topic_id }}")).to eq(99)
    end

    it "resolves node output references through pairedItem lineage" do
      node_context = {
        "$json" => {
          "id" => 2,
        },
        "$itemIndex" => 0,
        "__current_node_id" => "set",
        "__input_item" => {
          "json" => {
            "id" => 2,
          },
          "pairedItem" => {
            "item" => 1,
          },
        },
        "__input_items" => [{ "json" => { "id" => 2 }, "pairedItem" => { "item" => 1 } }],
        "__input_sources" => [{ "node_name" => "Filter", "output_index" => 0 }],
        "Split" => [
          { "json" => { "id" => 1, "label" => "first" }, "pairedItem" => { "item" => 0 } },
          { "json" => { "id" => 2, "label" => "second" }, "pairedItem" => { "item" => 0 } },
        ],
        "__node_runs" => {
          "Split" => [
            {
              "outputs" => [
                [
                  { "json" => { "id" => 1, "label" => "first" }, "pairedItem" => { "item" => 0 } },
                  { "json" => { "id" => 2, "label" => "second" }, "pairedItem" => { "item" => 0 } },
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
      }
      node_resolver = build_resolver(node_context)

      expect(node_resolver.resolve("={{ $('Split').item.json.label }}")).to eq("second")
    end

    it "does not guess an item when pairedItem lineage data is unavailable" do
      node_context = {
        "$json" => {
          "id" => 2,
        },
        "$itemIndex" => 0,
        "__current_node_id" => "set",
        "__input_sources" => [{ "node_name" => "Code", "output_index" => 0 }],
        "Split" => [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
        "__node_runs" => {
          "Split" => [
            {
              "outputs" => [
                [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
              ],
              "input_sources" => [{ "node_name" => "Source", "output_index" => 0 }],
            },
          ],
          "Code" => [
            {
              "outputs" => [[{ "json" => { "id" => 2 } }]],
              "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
            },
          ],
        },
      }
      node_resolver = build_resolver(node_context)

      expect(node_resolver.resolve("={{ $('Split').item.json.label }}")).to be_nil
      expect(node_resolver.expression_errors.last[:error]).to include(
        "Info for expression missing from previous node",
      )
    end

    it "defaults $().all() to the connected output branch" do
      node_context = {
        "$json" => {
        },
        "__current_node_id" => "set",
        "__input_sources" => [{ "node_name" => "If", "output_index" => 1 }],
        "If" => [{ "json" => { "branch" => "true" } }, { "json" => { "branch" => "false" } }],
        "__node_runs" => {
          "If" => [
            {
              "outputs" => [
                [{ "json" => { "branch" => "true" } }],
                [{ "json" => { "branch" => "false" } }],
              ],
            },
          ],
        },
      }
      node_resolver = build_resolver(node_context)

      expect(node_resolver.resolve("={{ $('If').all()[0].json.branch }}")).to eq("false")
      expect(node_resolver.resolve("={{ $('If').all(0)[0].json.branch }}")).to eq("true")
      expect(node_resolver.resolve("={{ $('If').all(2).length }}")).to eq(0)
    end

    it "uses the active resolver context when a shared sandbox is reused" do
      sandbox = DiscourseWorkflows::JsSandbox.new({})
      stale_resolver = described_class.new({ "$json" => { "id" => 1 } }, sandbox: sandbox)
      stale_resolver.resolve("={{ $json.id }}")
      stale_resolver.dispose

      active_context = {
        "$json" => {
          "id" => 2,
        },
        "$itemIndex" => 0,
        "__current_node_id" => "set",
        "__input_item" => {
          "json" => {
            "id" => 2,
          },
          "pairedItem" => {
            "item" => 1,
          },
        },
        "__input_items" => [{ "json" => { "id" => 2 }, "pairedItem" => { "item" => 1 } }],
        "__input_sources" => [{ "node_name" => "Filter", "output_index" => 0 }],
        "Split" => [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
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
              "outputs" => [[{ "json" => { "id" => 2 }, "pairedItem" => { "item" => 1 } }]],
              "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
            },
          ],
        },
      }
      active_resolver = described_class.new(active_context, sandbox: sandbox)

      expect(active_resolver.resolve("={{ $('Split').item.json.label }}")).to eq("second")
    ensure
      active_resolver&.dispose
      sandbox&.dispose
    end

    it "does not guess when pairedItem lineage matches multiple previous items" do
      node_context = {
        "$json" => {
          "merged" => true,
        },
        "$itemIndex" => 0,
        "__current_node_id" => "set",
        "__input_item" => {
          "json" => {
            "merged" => true,
          },
          "pairedItem" => {
            "item" => 0,
          },
        },
        "__input_items" => [{ "json" => { "merged" => true }, "pairedItem" => { "item" => 0 } }],
        "__input_sources" => [{ "node_name" => "Merge", "output_index" => 0 }],
        "Split" => [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
        "__node_runs" => {
          "Split" => [
            {
              "outputs" => [
                [{ "json" => { "label" => "first" } }, { "json" => { "label" => "second" } }],
              ],
              "input_sources" => [{ "node_name" => "Source", "output_index" => 0 }],
            },
          ],
          "Filter 1" => [
            {
              "outputs" => [
                [{ "json" => { "label" => "first" }, "pairedItem" => { "item" => 0 } }],
              ],
              "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
            },
          ],
          "Filter 2" => [
            {
              "outputs" => [
                [{ "json" => { "label" => "second" }, "pairedItem" => { "item" => 1 } }],
              ],
              "input_sources" => [{ "node_name" => "Split", "output_index" => 0 }],
            },
          ],
          "Merge" => [
            {
              "outputs" => [
                [
                  {
                    "json" => {
                      "merged" => true,
                    },
                    "pairedItem" => [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 0 }],
                  },
                ],
              ],
              "input_sources" => [
                { "node_name" => "Filter 1", "output_index" => 0 },
                { "node_name" => "Filter 2", "output_index" => 0 },
              ],
            },
          ],
        },
      }
      node_resolver = build_resolver(node_context)

      expect { node_resolver.resolve("={{ $('Split').item.json.label }}") }.to raise_error(
        RuntimeError,
        "Multiple matching items for expression",
      )
    end

    it "resolves node context references preserving type" do
      node_context = { "__node_contexts" => { "Approval" => { "approved" => true } } }
      node_resolver = build_resolver(context.merge(node_context, "$json" => context["$trigger"]))

      expect(node_resolver.resolve('={{ $("Approval").context["approved"] }}')).to be(true)
    end

    it "preserves array type for single-expression values" do
      expect(resolver.resolve("={{ $trigger.tags }}")).to eq(%w[bug help])
    end

    it "formats arrays when interpolating into a larger string" do
      expect(resolver.resolve("=tags: {{ $trigger.tags }}")).to eq("tags: bug, help")
    end

    it "returns nil for missing paths" do
      expect(resolver.resolve("={{ $trigger.nonexistent }}")).to be_nil
    end

    it "returns nil for missing node output paths" do
      node_resolver = build_resolver(context.merge("$json" => context["$trigger"]))

      expect(node_resolver.resolve("={{ $('Missing Step').item.json.topic_id }}")).to be_nil
    end

    it "returns nil for missing node context paths" do
      node_resolver = build_resolver(context.merge("$json" => context["$trigger"]))

      expect(node_resolver.resolve('={{ $("Missing Step").context["approved"] }}')).to be_nil
    end

    it "returns nil for invalid site settings" do
      expect(resolver.resolve("={{ $site_settings.nonexistent_setting_xyz }}")).to be_nil
    end

    it "returns an empty string for invalid site settings in mixed templates" do
      expect(resolver.resolve("=prefix-{{ $site_settings.nonexistent_setting_xyz }}")).to eq(
        "prefix-",
      )
    end

    it "resolves $vars expressions" do
      expect(resolver.resolve("={{ $vars.API_URL }}")).to eq("https://example.com")
    end

    it "returns nil for missing $vars" do
      expect(resolver.resolve("={{ $vars.nonexistent }}")).to be_nil
    end

    it "resolves $vars in mixed templates" do
      expect(resolver.resolve("={{ $vars.PREFIX }}-world")).to eq("hello-world")
    end
  end

  describe "JavaScript expressions" do
    it "evaluates .join() on arrays" do
      expect(resolver.resolve("={{ $json.tags.join(', ') }}")).to eq("bug, help")
    end

    it "evaluates JSON.stringify()" do
      result = resolver.resolve("={{ JSON.stringify($json.tags) }}")
      expect(result).to eq('["bug","help"]')
    end

    it "evaluates .length on arrays" do
      expect(resolver.resolve("={{ $json.tags.length }}")).to eq(2)
    end

    it "evaluates .includes() on arrays" do
      expect(resolver.resolve("={{ $json.tags.includes('bug') }}")).to be(true)
      expect(resolver.resolve("={{ $json.tags.includes('nope') }}")).to be(false)
    end

    it "evaluates ternary expressions" do
      expect(resolver.resolve("={{ $json.topic_id > 10 ? 'high' : 'low' }}")).to eq("high")
    end

    it "evaluates arithmetic" do
      expect(resolver.resolve("={{ $json.topic_id + 8 }}")).to eq(50)
    end

    it "evaluates string concatenation" do
      expect(resolver.resolve("={{ 'topic-' + $json.topic_id }}")).to eq("topic-42")
    end

    it "evaluates .toUpperCase() on strings" do
      ctx = { "$trigger" => { "name" => "hello" }, "$json" => { "name" => "hello" } }
      r = build_resolver(ctx)
      expect(r.resolve("={{ $json.name.toUpperCase() }}")).to eq("HELLO")
    end

    it "evaluates parseInt and parseFloat" do
      ctx = { "$json" => { "val" => "42.5" } }
      r = build_resolver(ctx)
      expect(r.resolve("={{ parseInt($json.val) }}")).to eq(42)
      expect(r.resolve("={{ parseFloat($json.val) }}")).to eq(42.5)
    end

    it "returns nil for JS errors" do
      expect(resolver.resolve("={{ $json.nonexistent.join(', ') }}")).to be_nil
    end

    it "works in template interpolation" do
      expect(resolver.resolve("=tags: {{ $json.tags.join(' | ') }}")).to eq("tags: bug | help")
    end

    it "evaluates node output references with JS methods" do
      node_context = { "Previous Step" => [{ "json" => { "items" => %w[a b c] } }] }
      r = build_resolver(node_context.merge("$json" => context["$trigger"]))
      expect(r.resolve("={{ $('Previous Step').first().json.items.join('-') }}")).to eq("a-b-c")
    end
  end

  describe "#resolve_hash" do
    it "resolves all string values in a hash" do
      config = {
        "topic_id" => "={{ $trigger.topic_id }}",
        "tag_name" => "resolved",
        "nested" => {
          "value" => "={{ $json.topic_id }}",
        },
      }

      result = resolver.resolve_hash(config)
      expect(result).to include(
        "topic_id" => 42,
        "tag_name" => "resolved",
        "nested" => include("value" => 42),
      )
    end

    it "resolves expressions inside arrays of hashes" do
      result = resolver.resolve_hash({ "items" => [{ "value" => "={{ $trigger.topic_id }}" }] })
      expect(result["items"][0]["value"]).to eq(42)
    end

    it "resolves expressions inside nested arrays" do
      result = resolver.resolve_hash({ "items" => [["={{ $trigger.topic_id }}"]] })
      expect(result["items"][0][0]).to eq(42)
    end
  end

  describe "#with_item" do
    it "rebinds $json for the duration of the block" do
      resolver = build_resolver(context.merge("$json" => context["$trigger"]))
      result_inside = nil
      result_outside_before = resolver.resolve("={{ $json.topic_id }}")

      resolver.with_item({ "topic_id" => 999 }) do
        result_inside = resolver.resolve("={{ $json.topic_id }}")
      end

      result_outside_after = resolver.resolve("={{ $json.topic_id }}")

      expect(result_outside_before).to eq(42)
      expect(result_inside).to eq(999)
      expect(result_outside_after).to eq(42)
    end

    it "keeps $input.item and $itemIndex in sync for the duration of the block" do
      resolver =
        build_resolver(
          context.merge(
            "$json" => context["$trigger"],
            "__input_item" => {
              "json" => context["$trigger"],
            },
            "__input_items" => [
              { "json" => context["$trigger"] },
              { "json" => { "topic_id" => 999 } },
            ],
            "__input_params" => {
              "operation" => "test",
            },
          ),
        )
      result_inside = nil

      resolver.with_item({ "json" => { "topic_id" => 999 } }, item_index: 1) do
        result_inside =
          resolver.resolve(
            "={{ [$json.topic_id, $input.item.json.topic_id, $input.first().json.topic_id, $input.last().json.topic_id, $input.params.operation, $itemIndex] }}",
          )
      end

      expect(result_inside).to eq([999, 999, 42, 999, "test", 1])
    end

    it "accepts symbol-keyed input items that already include json" do
      resolver = build_resolver(context.merge("$json" => context["$trigger"]))
      result_inside = nil

      resolver.with_item({ json: { topic_id: 999 } }) do
        result_inside = resolver.resolve("={{ $json.topic_id }}")
      end

      expect(result_inside).to eq(999)
    end

    it "restores $json even if the block raises" do
      resolver = build_resolver(context.merge("$json" => context["$trigger"]))
      expect { resolver.with_item({ "topic_id" => 999 }) { raise "boom" } }.to raise_error("boom")

      expect(resolver.resolve("={{ $json.topic_id }}")).to eq(42)
    end
  end

  describe "#expression_errors" do
    it "captures JS expression errors" do
      resolver = build_resolver({ "$json" => {} })
      resolver.resolve("={{ $json.nonexistent.toUpperCase() }}")
      expect(resolver.expression_errors.size).to eq(1)
      expect(resolver.expression_errors.first[:expression]).to eq("$json.nonexistent.toUpperCase()")
      expect(resolver.expression_errors.first[:error]).to be_present
    end

    it "is empty when no errors occur" do
      resolver = build_resolver({ "$json" => { "name" => "test" } })
      resolver.resolve("={{ $json.name }}")
      expect(resolver.expression_errors).to be_empty
    end
  end

  describe "shared sandbox" do
    it "reuses a shared sandbox across resolver instances" do
      sandbox = DiscourseWorkflows::JsSandbox.new({})

      resolver_a = described_class.new({ "$json" => { "a" => 1 } }, sandbox: sandbox)
      expect(resolver_a.resolve("={{ $json.a }}")).to eq(1)
      resolver_a.dispose

      resolver_b = described_class.new({ "$json" => { "b" => 2 } }, sandbox: sandbox)
      expect(resolver_b.resolve("={{ $json.b }}")).to eq(2)
      resolver_b.dispose

      expect(sandbox.js_context).not_to be_nil
    ensure
      sandbox&.dispose
    end

    it "propagates workflow budget errors from the shared sandbox" do
      Process.stubs(:clock_gettime).returns(0.0)

      sandbox =
        DiscourseWorkflows::JsSandbox.new(
          {},
          budget_tracker: DiscourseWorkflows::SandboxBudget.new({}, budget_ms: 10),
        )
      resolver = described_class.new({ "$json" => { "a" => 1 } }, sandbox: sandbox)

      Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 0.02)

      expect { resolver.resolve("={{ $json.a }}") }.to raise_error(
        DiscourseWorkflows::JsSandbox::BudgetExceededError,
      )
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end

  describe "#resolve_segments" do
    it "returns plaintext for text without expressions" do
      segments = resolver.resolve_segments("hello world")
      expect(segments).to eq([{ kind: "plaintext", text: "hello world" }])
    end

    it "returns a resolved segment for a valid expression" do
      segments = resolver.resolve_segments("{{ $json.topic_id }}")
      expect(segments.size).to eq(1)
      expect(segments[0][:kind]).to eq("resolved")
      expect(segments[0][:state]).to eq("valid")
      expect(segments[0][:text]).to eq("42")
      expect(segments[0][:from]).to eq(0)
      expect(segments[0][:to]).to eq("{{ $json.topic_id }}".length)
    end

    it "returns mixed segments for text with expressions" do
      segments = resolver.resolve_segments("id: {{ $json.topic_id }}!")
      expect(segments.size).to eq(3)
      expect(segments[0]).to eq({ kind: "plaintext", text: "id: " })
      expect(segments[1][:kind]).to eq("resolved")
      expect(segments[1][:state]).to eq("valid")
      expect(segments[2]).to eq({ kind: "plaintext", text: "!" })
    end

    it "marks undefined references" do
      segments = resolver.resolve_segments("{{ undefined_var }}")
      expect(segments[0][:state]).to eq("undefined")
    end

    it "marks syntax errors as invalid" do
      segments = resolver.resolve_segments("{{ if( }}")
      expect(segments[0][:state]).to eq("invalid")
    end

    it "marks uncalled functions as warning" do
      segments = resolver.resolve_segments("{{ $json.tags.join }}")
      expect(segments[0][:state]).to eq("warning")
    end

    it "marks empty expressions" do
      segments = resolver.resolve_segments("{{  }}")
      expect(segments[0][:state]).to eq("empty")
    end

    it "treats unclosed {{ as plaintext" do
      segments = resolver.resolve_segments("hello {{ $json.title")
      expect(segments.last[:kind]).to eq("plaintext")
      expect(segments.last[:text]).to include("{{")
    end
  end

  describe ".resolve" do
    fab!(:user)

    it "resolves a single expression without manual lifecycle" do
      result =
        described_class.resolve(
          "={{ $json.topic_id }}",
          context: {
            "$json" => {
              "topic_id" => 42,
            },
          },
        )
      expect(result).to eq(42)
    end

    it "returns non-expression values as-is" do
      expect(described_class.resolve("hello", context: {})).to eq("hello")
    end

    it "passes user to the resolver" do
      result = described_class.resolve("={{ $current_user.username }}", context: {}, user: user)
      expect(result).to eq(user.username)
    end
  end

  describe ".resolve_hash" do
    it "resolves a hash without manual lifecycle" do
      result =
        described_class.resolve_hash(
          { "id" => "={{ $json.topic_id }}", "fixed" => "hello" },
          context: {
            "$json" => {
              "topic_id" => 42,
            },
          },
        )
      expect(result).to eq({ "id" => 42, "fixed" => "hello" })
    end
  end

  describe ".resolve_segments" do
    fab!(:user)

    it "passes user through to the resolver" do
      segments =
        described_class.resolve_segments("{{ $current_user.username }}", context: {}, user: user)

      expect(segments.first[:text]).to eq(user.username)
    end

    it "returns an empty array and logs a warning on MiniRacer::Error" do
      fake_resolver = instance_double(described_class)
      allow(fake_resolver).to receive(:resolve_segments).and_raise(MiniRacer::Error.new("boom"))
      allow(fake_resolver).to receive(:dispose)
      allow(described_class).to receive(:new).and_return(fake_resolver)
      allow(Rails.logger).to receive(:warn)

      expect(described_class.resolve_segments("{{ x }}", context: {})).to eq([])
      expect(Rails.logger).to have_received(:warn).with(/Expression evaluation failed: boom/)
    end
  end
end
