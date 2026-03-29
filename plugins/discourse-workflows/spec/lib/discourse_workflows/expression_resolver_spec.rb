# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionResolver do
  subject(:resolver) { described_class.new(context.merge("$json" => context["trigger"])) }

  let(:context) { { "trigger" => { "topic_id" => 42, "tags" => %w[bug help] } } }

  describe "#resolve" do
    it "returns non-string values as-is" do
      expect(resolver.resolve(42)).to eq(42)
      expect(resolver.resolve(true)).to eq(true)
      expect(resolver.resolve(nil)).to be_nil
    end

    it "returns fixed strings as-is" do
      expect(resolver.resolve("hello")).to eq("hello")
    end

    it "resolves context dot-path expressions preserving type" do
      expect(resolver.resolve("={{ trigger.topic_id }}")).to eq(42)
    end

    it "resolves $json expressions preserving type" do
      expect(resolver.resolve("={{ $json.topic_id }}")).to eq(42)
    end

    it "resolves $site_settings expressions" do
      SiteSetting.title = "My Forum"
      expect(resolver.resolve("={{ $site_settings.title }}")).to eq("My Forum")
    end

    it "handles mixed literal and expression" do
      expect(resolver.resolve("=topic-{{ trigger.topic_id }}-closed")).to eq("topic-42-closed")
    end

    it "handles multiple expressions" do
      expect(resolver.resolve("={{ trigger.topic_id }}-{{ $json.topic_id }}")).to eq("42-42")
    end

    it "resolves node output references preserving type" do
      node_context = {
        "Previous Step" => [{ "json" => { "topic_id" => 99, "tags" => %w[dev ops] } }],
      }

      node_resolver = described_class.new(node_context.merge("$json" => context["trigger"]))

      expect(node_resolver.resolve("={{ $('Previous Step').item.json.topic_id }}")).to eq(99)
    end

    it "resolves node context references preserving type" do
      node_context = { "_node_contexts" => { "Approval" => { "approved" => true } } }
      node_resolver =
        described_class.new(context.merge(node_context, "$json" => context["trigger"]))

      expect(node_resolver.resolve('={{ $("Approval").context["approved"] }}')).to eq(true)
    end

    it "preserves array type for single-expression values" do
      expect(resolver.resolve("={{ trigger.tags }}")).to eq(%w[bug help])
    end

    it "preserves integer type for single-expression values" do
      expect(resolver.resolve("={{ trigger.topic_id }}")).to eq(42)
    end

    it "still returns string for mixed templates" do
      result = resolver.resolve("=hello {{ trigger.topic_id }}!")
      expect(result).to eq("hello 42!")
    end

    it "formats arrays when interpolating into a larger string" do
      expect(resolver.resolve("=tags: {{ trigger.tags }}")).to eq("tags: bug, help")
    end

    it "returns nil for missing paths" do
      expect(resolver.resolve("={{ trigger.nonexistent }}")).to be_nil
    end

    it "returns nil for missing node output paths" do
      node_resolver = described_class.new(context.merge("$json" => context["trigger"]))

      expect(node_resolver.resolve("={{ $('Missing Step').item.json.topic_id }}")).to be_nil
    end

    it "returns nil for missing node context paths" do
      node_resolver = described_class.new(context.merge("$json" => context["trigger"]))

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
      Fabricate(:discourse_workflows_variable, key: "API_URL", value: "https://example.com")
      expect(resolver.resolve("={{ $vars.API_URL }}")).to eq("https://example.com")
    end

    it "returns nil for missing $vars" do
      expect(resolver.resolve("={{ $vars.nonexistent }}")).to be_nil
    end

    it "resolves $vars in mixed templates" do
      Fabricate(:discourse_workflows_variable, key: "PREFIX", value: "hello")
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
      expect(resolver.resolve("={{ $json.tags.includes('bug') }}")).to eq(true)
      expect(resolver.resolve("={{ $json.tags.includes('nope') }}")).to eq(false)
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
      ctx = { "trigger" => { "name" => "hello" }, "$json" => { "name" => "hello" } }
      r = described_class.new(ctx)
      expect(r.resolve("={{ $json.name.toUpperCase() }}")).to eq("HELLO")
    end

    it "evaluates parseInt and parseFloat" do
      ctx = { "$json" => { "val" => "42.5" } }
      r = described_class.new(ctx)
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
      r = described_class.new(node_context.merge("$json" => context["trigger"]))
      expect(r.resolve("={{ $('Previous Step').item.json.items.join('-') }}")).to eq("a-b-c")
    end
  end

  describe "#resolve_hash" do
    it "resolves all string values in a hash" do
      config = {
        "topic_id" => "={{ trigger.topic_id }}",
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
      result = resolver.resolve_hash({ "items" => [{ "value" => "={{ trigger.topic_id }}" }] })
      expect(result["items"][0]["value"]).to eq(42)
    end

    it "resolves expressions inside nested arrays" do
      result = resolver.resolve_hash({ "items" => [["={{ trigger.topic_id }}"]] })
      expect(result["items"][0][0]).to eq(42)
    end
  end
end
