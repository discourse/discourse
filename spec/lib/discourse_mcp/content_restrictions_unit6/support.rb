# frozen_string_literal: true

module McpContentRestrictionsUnit6
  def forum_config
    {
      "allow" => {
        "mode" => "all",
        "category_ids" => [],
        "tag_ids" => [],
      },
      "deny" => {
        "category_ids" => [],
        "tag_ids" => [],
      },
    }
  end

  def register_rule(name, **options)
    registry.register_content_rule_kind(
      name,
      provider: "u6",
      affected_data_kinds: ["topics"],
      config_contract: {
        type: "object",
        additionalProperties: false,
      },
      compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      **options,
    )
  end

  def register_primitive(
    identifier,
    content:,
    kind: :tool,
    enabled: true,
    blocked: false,
    available: true
  )
    registry.register(
      identifier: identifier,
      kind: kind,
      title: identifier,
      description: "Unit six request oracle",
      implementation: ->(**) { raise "Request oracle must not invoke primitives" },
      content: content,
      availability: -> { available },
      required_scopes: ["mcp:profile:read"],
    )
    McpPrimitive.create!(
      kind: kind,
      identifier: identifier,
      enabled: enabled,
      emergency_blocked: blocked,
    )
  end

  def rule_entry(name)
    response.parsed_body.fetch("rule_kinds").find { |entry| entry.fetch("name") == name }
  end

  def history(action)
    UserHistory.where(custom_type: action).order(:id).last
  end

  def primitive_id(identifier, kind = :tool)
    "#{kind}:#{identifier}"
  end

  def content_get
    get "/admin/mcp/content-restrictions.json"
    expect(response.status).to eq(200)
  end
end

RSpec.shared_context "with unit six request registry" do
  include McpContentRestrictionsUnit6

  fab!(:admin)
  let(:registry) { DiscourseMcp::Registry.new }
  let(:untouched) do
    %w[topics categories tags private_messages exit_paths].index_with { :untouched }
  end
  let(:filtered) { untouched.merge("topics" => :enforced, "private_messages" => :enforced) }

  before do
    McpContentRule.delete_all
    McpPrimitive.delete_all
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseMcp::CorePrimitives.register_content_kinds(registry)
    allow(DiscourseMcp).to receive(:registry).and_return(registry)
    register_primitive("u6_none", content: :none)
    register_primitive("u6_untouched", content: untouched)
    register_primitive("u6_filtered", content: filtered)
    register_primitive("u6_forum", content: untouched.merge("topics" => :unenforced))
    register_primitive("u6_pm", content: untouched.merge("private_messages" => :unenforced))
    register_primitive("u6_exit", content: untouched.merge("exit_paths" => :unenforced))
    register_primitive("u6_undeclared", content: nil)
    register_primitive("u6_unbounded", content: :unbounded)
    register_primitive("u6_disabled", content: nil, enabled: false)
    register_primitive("u6_emergency", content: nil, blocked: true)
    register_primitive("u6_unavailable", content: nil, available: false)
    register_primitive("u6_resource", content: nil, kind: :resource)
    register_primitive("u6_template", content: filtered, kind: :resource_template)
    register_primitive("u6_prompt", content: nil, kind: :prompt)
  end
end
