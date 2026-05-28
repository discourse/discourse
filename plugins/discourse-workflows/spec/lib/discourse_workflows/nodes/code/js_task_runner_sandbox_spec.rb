# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Code::JsTaskRunnerSandbox do
  let(:input_items) { [{ "json" => { "name" => "Ada" } }] }
  let(:runner) { described_class.new("manual", exec_ctx) }

  def build_exec_ctx(items = input_items)
    resolver_context = { "$json" => items.first&.dig("json") || {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: items,
        parameters: {
        },
        resolver: resolver,
        resolver_context: resolver_context,
      )
    [ctx, resolver, sandbox]
  end

  before { @exec_ctx, @resolver, @sandbox = build_exec_ctx }
  after do
    @resolver&.dispose
    @sandbox&.dispose
  end

  let(:exec_ctx) { @exec_ctx }

  describe "#run_code_all_items" do
    it "normalizes all-items JavaScript results" do
      result = runner.run_code_all_items("return [{ name: $input.first().json.name }];")

      expect(result).to eq([{ "json" => { "name" => "Ada" } }])
    end

    it "binds $json to the first input item" do
      result = runner.run_code_all_items("return { name: $json.name };")

      expect(result).to eq([{ "json" => { "name" => "Ada" } }])
    end

    it "raises node validation errors for mixed item formats" do
      expect {
        runner.run_code_all_items("return [{ json: { id: 1 } }, { id: 2 }];")
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown top-level item key: id/)
    end

    it "raises node validation errors for unsupported top-level binary items" do
      expect {
        runner.run_code_all_items("return [{ json: { id: 1 } }, { binary: {} }];")
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown top-level item key: binary/)
    end
  end

  describe "#run_code_for_each_item" do
    it "adds pairedItem metadata for per-item JavaScript results" do
      result = runner.run_code_for_each_item("return { name: $json.name };", input_items.length)

      expect(result).to eq([{ "json" => { "name" => "Ada" }, "pairedItem" => { "item" => 0 } }])
    end

    it "rejects all-items helpers in per-item mode" do
      expect {
        runner.run_code_for_each_item("return { count: $input.all().length };", input_items.length)
      }.to raise_error(DiscourseWorkflows::NodeError, /Can't use \.all\(\) here/)
    end
  end

  describe "#run_code" do
    it "runs raw JavaScript with additional properties" do
      runner = described_class.new("manual", exec_ctx, nil, { "items" => input_items.deep_dup })

      result = runner.run_code("return items.map(function(item) { return item.json.name; });")

      expect(result).to eq(["Ada"])
    end

    it "raises node errors for task runner failures without exception objects" do
      execute_functions =
        Class
          .new do
            def continue_on_fail
              false
            end

            def start_job(*)
              DiscourseWorkflows::Executor::NodeExecutionContext::JobResult.new(
                ok: false,
                result: nil,
                error: "broken",
              )
            end
          end
          .new
      runner = described_class.new("manual", execute_functions)

      expect { runner.run_code("return 1;") }.to raise_error(
        DiscourseWorkflows::NodeError,
        "JavaScript execution failed: broken",
      )
    end
  end
end
