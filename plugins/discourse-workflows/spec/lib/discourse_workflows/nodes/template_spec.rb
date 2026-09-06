# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Template::V1 do
  fab!(:admin)

  fab!(:workflow) do
    Fabricate(:discourse_workflows_workflow, name: "Template workflow", created_by: admin)
  end

  fab!(:execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

  subject(:template_result) { described_class.new.execute(execution_context).first }

  let(:template) { nil }
  let(:mode) { nil }
  let(:template_parameters) { { "template" => template, "mode" => mode }.compact }
  let(:execution_items) { [{ "json" => {} }] }
  let(:input_groups) { nil }
  let(:template_vars) { {} }
  let(:workflow_context) { nil }
  let(:execution_id) { nil }
  let(:resolver_context) { { "$json" => execution_items.first&.dig("json") || {} } }
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new(resolver_context, vars: template_vars) }
  let(:resolver) { DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox) }
  let(:execution_context) do
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: execution_items,
      input_groups: input_groups,
      parameters: template_parameters,
      property_schema: described_class.property_schema,
      resolver: resolver,
      vars: template_vars,
      workflow: workflow_context,
      execution_id: execution_id,
    )
  end

  after do
    resolver.dispose
    sandbox.dispose
  end

  describe "#execute" do
    context "with multiple input items" do
      let(:template) { "{% for item in items %}{{ item.name }} {% endfor %}" }
      let(:execution_items) do
        [{ "json" => { "name" => "Alice" } }, { "json" => { "name" => "Bob" } }]
      end

      it "renders a single output from all input items" do
        expect(template_result.map { |item| item["json"] }).to eq([{ "template" => "Alice Bob " }])
      end

      it "links the output item to every source item" do
        expect(template_result.first["pairedItem"]).to eq([{ "item" => 0 }, { "item" => 1 }])
      end
    end

    context "in each-item mode" do
      let(:template) do
        "{{ item.name }} {{ item.item_index }}/{{ items_count }} {{ site_settings.title }}"
      end
      let(:mode) { "runOnceForEachItem" }
      let(:execution_items) do
        [
          { "json" => { "name" => "Alice", "item_index" => 99 } },
          { "json" => { "name" => "Bob", "items_count" => 99 } },
        ]
      end

      it "renders one output per input item" do
        SiteSetting.title = "Each Item Forum"

        expect(template_result.map { |item| item["json"] }).to eq(
          [
            { "template" => "Alice 1/2 Each Item Forum" },
            { "template" => "Bob 2/2 Each Item Forum" },
          ],
        )
        expect(template_result.map { |item| item["pairedItem"] }).to eq(
          [{ "item" => 0 }, { "item" => 1 }],
        )
      end
    end

    context "with workflow metadata and variables" do
      let(:template) do
        "{% for item in items %}{{ item.name }} {% endfor %}" \
          "count={{ items_count }} var={{ vars.project }} " \
          "workflow={{ workflow.name }} execution={{ execution.id }} " \
          "{% for item in items %}item={{ item.item.json.name }} index={{ item.item_index }} {% endfor %}"
      end
      let(:execution_items) do
        [
          {
            "json" => {
              "name" => "Alice",
              "vars" => {
                "project" => "Ignored",
              },
              "item" => {
                "json" => {
                  "name" => "Ignored",
                },
              },
              "item_index" => 99,
            },
          },
          { "json" => { "name" => "Bob" } },
        ]
      end
      let(:template_vars) { { "project" => "Workflows" } }
      let(:workflow_context) { workflow }
      let(:execution_id) { execution.id }

      it "exposes them with all input items" do
        expect(template_result.first["json"]).to eq(
          "template" =>
            "Alice Bob count=2 var=Workflows workflow=Template workflow execution=#{execution.id} " \
              "item=Alice index=1 item=Bob index=2 ",
        )
      end
    end

    context "with site settings" do
      let(:template) do
        "title={{ site_settings.title }} " \
          "secret={{ site_settings.discourse_connect_secret }} " \
          "hidden={{ site_settings.vapid_public_key }}"
      end

      it "exposes public settings and filters private settings" do
        SiteSetting.title = "Liquid Forum"

        expect(template_result.first["json"]).to eq(
          "template" => "title=Liquid Forum secret=[FILTERED] hidden=[FILTERED]",
        )
      end
    end

    context "with extra fields in an input item" do
      let(:template) { "{% for item in items %}{{ item.name }}{% endfor %}" }
      let(:execution_items) { [{ "json" => { "name" => "Alice", "extra" => "ignored" } }] }

      it "emits only the template field", :aggregate_failures do
        expect(template_result.first["json"]).to eq("template" => "Alice")
        expect(template_result.first["json"]).to match_node_output_schema(described_class)
      end
    end

    context "with missing variables" do
      let(:template) { "Hello {{ missing }}" }

      it "renders them as blank strings" do
        expect(template_result.first["json"]).to eq("template" => "Hello ")
      end
    end

    context "with HTML in a value" do
      let(:template) { "{% for item in items %}{{ item.value }}{% endfor %}" }
      let(:execution_items) { [{ "json" => { "value" => "<b>bold</b>" } }] }

      it "uses default Liquid output rules" do
        expect(template_result.first["json"]).to eq("template" => "<b>bold</b>")
      end
    end

    context "without a template" do
      let(:execution_items) do
        [{ "json" => { "name" => "Alice" } }, { "json" => { "name" => "Bob" } }]
      end

      it "defaults to one showing item loop syntax" do
        expect(template_result.first["json"]).to eq("template" => <<~TEXT)
            Items:
            - 1: Alice
            - 2: Bob
          TEXT
      end
    end

    context "with invalid Liquid syntax" do
      let(:template) { "{% for item in items %}" }

      it "raises a node error" do
        expect { template_result }.to raise_error(DiscourseWorkflows::NodeError, /Invalid template/)
      end
    end

    context "with an invalid mode" do
      let(:template) { "Hello" }
      let(:mode) { "invalid" }

      it "raises a node error" do
        expect { template_result }.to raise_error(
          DiscourseWorkflows::NodeError,
          /Invalid Template mode/,
        )
      end
    end
  end

  describe "multiple inputs" do
    it "accepts several connections on its main input" do
      expect(described_class.input_ports).to contain_exactly(
        include(key: "main", required: false, multiple: true),
      )
    end

    context "with several connected branches" do
      let(:template) do
        "{% for u in inputs[1] %}@{{ u.username }} {% endfor %}| {{ inputs[0][0].title }}"
      end
      let(:execution_items) { [{ "json" => { "title" => "Topics" } }] }
      let(:input_groups) do
        {
          "input_1" => [{ "json" => { "title" => "Topics" } }],
          "input_2" => [
            { "json" => { "username" => "ann" } },
            { "json" => { "username" => "bob" } },
          ],
        }
      end

      it "exposes each connected branch under inputs" do
        expect(template_result.first["json"]).to eq("template" => "@ann @bob | Topics")
      end
    end

    context "with a template reading items" do
      let(:template) { "{{ items[0].title }}/{{ items_count }}" }
      let(:execution_items) { [{ "json" => { "title" => "Topics" } }] }
      let(:input_groups) do
        {
          "input_1" => [{ "json" => { "title" => "Topics" } }],
          "input_2" => [{ "json" => { "username" => "ann" } }],
        }
      end

      it "keeps items pointing at the first input" do
        expect(template_result.first["json"]).to eq("template" => "Topics/1")
      end
    end

    context "with a single connected input" do
      let(:template) { "{{ inputs[0][0].name }}" }
      let(:execution_items) { [{ "json" => { "name" => "Alice" } }] }

      it "exposes it as inputs[0]" do
        expect(template_result.first["json"]).to eq("template" => "Alice")
      end
    end
  end

  describe "resource limits" do
    context "with a runaway loop without a ceiling" do
      let(:template) { "{% for i in (1..1000000) %}x{% endfor %}" }

      it "raises a node error instead of rendering it" do
        expect { template_result }.to raise_error(DiscourseWorkflows::NodeError, /Invalid template/)
      end
    end

    context "with a report-sized template" do
      let(:template) do
        "{% for t in items %}{{ t.title }}{% for p in t.posts %} {{ p.n }}{% endfor %}\n{% endfor %}"
      end
      let(:execution_items) do
        (1..20).map do |index|
          { "json" => { "title" => "Topic #{index}", "posts" => (1..20).map { |n| { "n" => n } } } }
        end
      end

      it "renders well within the limits" do
        expect(template_result.first["json"]["template"].lines.length).to eq(20)
      end
    end
  end
end
