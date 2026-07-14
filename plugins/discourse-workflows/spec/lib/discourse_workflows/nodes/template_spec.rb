# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Template::V1 do
  fab!(:admin)

  fab!(:workflow) do
    Fabricate(:discourse_workflows_workflow, name: "Template workflow", created_by: admin)
  end

  fab!(:execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

  def execute_template(
    template = nil,
    mode: nil,
    input_items: [{ "json" => {} }],
    vars: {},
    workflow: nil,
    execution_id: nil
  )
    parameters = template.nil? ? {} : { "template" => template }
    parameters["mode"] = mode if mode
    resolver_context = { "$json" => input_items.first&.dig("json") || {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context, vars: vars)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    exec_ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: input_items,
        parameters: parameters,
        property_schema: described_class.property_schema,
        resolver: resolver,
        vars: vars,
        workflow: workflow,
        execution_id: execution_id,
      )

    described_class.new.execute(exec_ctx).first
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  describe "#execute" do
    it "renders a single output from all input items" do
      result =
        execute_template(
          "{% for item in items %}{{ item.name }} {% endfor %}",
          input_items: [{ "json" => { "name" => "Alice" } }, { "json" => { "name" => "Bob" } }],
        )

      expect(result.map { |item| item["json"] }).to eq([{ "template" => "Alice Bob " }])
    end

    it "renders one output per input item in each-item mode" do
      SiteSetting.title = "Each Item Forum"

      result =
        execute_template(
          "{{ item.name }} {{ item.item_index }}/{{ items_count }} {{ site_settings.title }}",
          mode: "runOnceForEachItem",
          input_items: [
            { "json" => { "name" => "Alice", "item_index" => 99 } },
            { "json" => { "name" => "Bob", "items_count" => 99 } },
          ],
        )

      expect(result.map { |item| item["json"] }).to eq(
        [
          { "template" => "Alice 1/2 Each Item Forum" },
          { "template" => "Bob 2/2 Each Item Forum" },
        ],
      )
      expect(result.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 1 }])
    end

    it "exposes workflow metadata and all input items" do
      input_items = [
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

      result =
        execute_template(
          "{% for item in items %}{{ item.name }} {% endfor %}" \
            "count={{ items_count }} var={{ vars.project }} " \
            "workflow={{ workflow.name }} execution={{ execution.id }} " \
            "{% for item in items %}item={{ item.item.json.name }} index={{ item.item_index }} {% endfor %}",
          input_items: input_items,
          vars: {
            "project" => "Workflows",
          },
          workflow: workflow,
          execution_id: execution.id,
        )

      expect(result.first["json"]).to eq(
        "template" =>
          "Alice Bob count=2 var=Workflows workflow=Template workflow execution=#{execution.id} " \
            "item=Alice index=1 item=Bob index=2 ",
      )
    end

    it "exposes site settings and filters private settings" do
      SiteSetting.title = "Liquid Forum"

      result =
        execute_template(
          "title={{ site_settings.title }} " \
            "secret={{ site_settings.discourse_connect_secret }} " \
            "hidden={{ site_settings.vapid_public_key }}",
        )

      expect(result.first["json"]).to eq(
        "template" => "title=Liquid Forum secret=[FILTERED] hidden=[FILTERED]",
      )
    end

    it "emits only the template field" do
      result =
        execute_template(
          "{% for item in items %}{{ item.name }}{% endfor %}",
          input_items: [{ "json" => { "name" => "Alice", "extra" => "ignored" } }],
        )

      expect(result.first["json"]).to eq("template" => "Alice")
    end

    it "links the output item to every source item" do
      result =
        execute_template(
          "{% for item in items %}{{ item.name }}{% endfor %}",
          input_items: [{ "json" => { "name" => "Alice" } }, { "json" => { "name" => "Bob" } }],
        )

      expect(result.first["pairedItem"]).to eq([{ "item" => 0 }, { "item" => 1 }])
    end

    it "renders missing variables as blank strings" do
      result = execute_template("Hello {{ missing }}")

      expect(result.first["json"]).to eq("template" => "Hello ")
    end

    it "uses default Liquid output rules" do
      result =
        execute_template(
          "{% for item in items %}{{ item.value }}{% endfor %}",
          input_items: [{ "json" => { "value" => "<b>bold</b>" } }],
        )

      expect(result.first["json"]).to eq("template" => "<b>bold</b>")
    end

    it "defaults to a template showing item loop syntax" do
      result =
        execute_template(
          input_items: [{ "json" => { "name" => "Alice" } }, { "json" => { "name" => "Bob" } }],
        )

      expect(result.first["json"]).to eq("template" => <<~TEXT)
          Items:
          - 1: Alice
          - 2: Bob
        TEXT
    end

    it "raises a node error for invalid Liquid syntax" do
      expect { execute_template("{% for item in items %}") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Invalid template/,
      )
    end

    it "raises a node error for invalid mode" do
      expect { execute_template("Hello", mode: "invalid") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Invalid Template mode/,
      )
    end
  end
end
