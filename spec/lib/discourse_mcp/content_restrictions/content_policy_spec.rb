# frozen_string_literal: true

describe DiscourseMcp do
  let(:registry) { DiscourseMcp::Registry.new }
  let(:core_kinds) { %w[topics private_messages categories tags exit_paths] }
  let(:declaration) { core_kinds.index_with { :untouched } }

  def primitive(content = nil, provider: "core", identifier: "oracle_tool")
    DiscourseMcp::Primitive.new(
      identifier:,
      kind: :tool,
      title: "Oracle tool",
      description: "Exercises the public content gate",
      implementation: ->(**) { raise "Oracle implementation invoked" },
      provider:,
      content:,
    )
  end

  def prepare_registry
    core_kinds.each { |name| registry.register_content_data_kind(name, provider: "core") }
    allow(DiscourseMcp).to receive(:registry).and_return(registry)
  end

  def register_rule(name = "oracle:rule", **attributes)
    registry.register_content_rule_kind(
      name,
      provider: "oracle",
      affected_data_kinds: ["private_messages"],
      config_contract: {
        type: "object",
        additionalProperties: false,
      },
      compile: ->(_config) { ->(**) { false } },
      **attributes,
    )
  end

  it "stores one non-null JSON configuration per rule kind with nullable updater and timestamps" do
    columns = McpContentRule.columns.index_by(&:name)
    expect(columns.fetch("rule_kind")).to have_attributes(type: :string, null: false)
    expect(columns.fetch("config")).to have_attributes(sql_type: "jsonb", null: false)
    expect(columns.fetch("updated_by_id")).to have_attributes(type: :integer, null: true)
    rule = McpContentRule.create!(rule_kind: "private_messages")
    expect(rule.reload).to have_attributes(config: {}, updated_by_id: nil)
    expect([rule.created_at, rule.updated_at]).to all(be_present)
    expect(
      McpContentRule
        .connection
        .indexes(:mcp_content_rules)
        .any? { |index| index.unique && index.columns == ["rule_kind"] },
    ).to eq(true)
    expect do
      McpContentRule.transaction(requires_new: true) do
        McpContentRule.insert_all!(
          [
            {
              rule_kind: rule.rule_kind,
              config: {
              },
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "normalizes and freezes declarations while preserving nil none and unbounded" do
    expect(primitive.content).to be_nil
    expect(primitive(:none).content).to eq(:none)
    expect(primitive(:unbounded).content).to eq(:unbounded)
    source = {
      :private_messages => "enforced",
      "exit_paths" => :untouched,
      "chat:messages" => "unenforced",
    }
    declared = primitive(source).content
    expect(declared).to eq(
      "private_messages" => :enforced,
      "exit_paths" => :untouched,
      "chat:messages" => :unenforced,
    )
    expect(declared).to be_frozen
    source[:private_messages] = :unenforced
    expect(declared.fetch("private_messages")).to eq(:enforced)
  end

  it "rejects invalid declarations at construction without rejecting unknown well-formed keys" do
    invalid = [
      :all,
      "none",
      [],
      1,
      true,
      { topics: :safe },
      { topics: nil },
      { topics: 1 },
      { "" => :enforced },
      { "Topics" => :enforced },
      { "chat:" => :enforced },
      { ":messages" => :enforced },
      { "chat:messages:extra" => :enforced },
      { "bad name" => :enforced },
      { 1 => :enforced },
    ]
    invalid.each do |content|
      aggregate_failures(content.inspect) do
        expect { primitive(content) }.to raise_error(ArgumentError)
      end
    end
    expect(primitive({ "unknown_core" => :enforced }).content).to eq("unknown_core" => :enforced)
    expect(primitive({ "future:messages" => :enforced }).content).to eq(
      "future:messages" => :enforced,
    )
  end

  it "validates data-kind namespaces and duplicates across providers" do
    registry.register_content_data_kind("topics", provider: "core")
    registry.register_content_data_kind(
      "chat:messages",
      provider: "chat",
      touched_by: ["foreign_tool"],
    )
    [
      %w[topics core],
      %w[chat:messages chat],
      %w[messages chat],
      %w[other:messages chat],
      %w[chat: chat],
      %w[chat:Bad chat],
      %w[chat:messages:extra chat],
      %w[Bad core],
      ["bad name", "core"],
    ].each do |name, provider|
      aggregate_failures("#{provider}/#{name}") do
        expect { registry.register_content_data_kind(name, provider:) }.to raise_error(
          ArgumentError,
        )
      end
    end
  end

  it "validates rule namespaces duplicates and referenced data kinds" do
    prepare_registry
    register_rule
    expect { register_rule }.to raise_error(ArgumentError)
    %w[rule other:rule oracle: Oracle:rule oracle:rule:extra].each do |name|
      expect { register_rule(name) }.to raise_error(ArgumentError)
    end
    expect do
      register_rule("oracle:missing", affected_data_kinds: ["absent:messages"])
    end.to raise_error(ArgumentError)
    register_rule(
      "oracle:available",
      admin_component_id: "oracle-editor",
      availability: -> { true },
    )
  end

  it "rebuilds the five core data kinds and PM rule on registry reset" do
    original = DiscourseMcp.registry
    rebuilt = DiscourseMcp.reset_registry!
    expect(rebuilt).to equal(DiscourseMcp.registry)
    core_kinds.each do |name|
      expect { rebuilt.register_content_data_kind(name, provider: "core") }.to raise_error(
        ArgumentError,
      )
    end
    expect do
      rebuilt.register_content_rule_kind(
        "private_messages",
        provider: "core",
        affected_data_kinds: ["private_messages"],
        config_contract: {
          type: "object",
        },
        compile: ->(_config) { ->(**) { false } },
      )
    end.to raise_error(ArgumentError)
  ensure
    DiscourseMcp.instance_variable_set(:@registry, original) if original
  end

  it "permits every declaration without rows and reloads policy after insertion and deletion" do
    expect(DiscourseMcp::ContentPolicy.load).not_to be_active
    [nil, :none, :unbounded, {}, { unknown_core: :unenforced }].each do |content|
      expect(DiscourseMcp.primitive_usable?(primitive(content))).to eq(true)
    end
    rule = McpContentRule.create!(rule_kind: "private_messages", config: {})
    policy = DiscourseMcp::ContentPolicy.load
    expect(policy).to be_active
    expect(policy).not_to be_orphaned
    expect(policy.revoked_scopes).to contain_exactly(
      "mcp:private-messages:read",
      "mcp:private-messages:write",
    )
    expect(DiscourseMcp.primitive_usable?(primitive)).to eq(false)
    rule.destroy!
    expect(DiscourseMcp::ContentPolicy.load.revoked_scopes).to be_empty
    expect(DiscourseMcp.primitive_usable?(primitive)).to eq(true)
  end

  it "applies the active-rule gate to nil none unbounded and PM and exit-path declarations" do
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    expectations = [
      [nil, false],
      [:none, true],
      [:unbounded, false],
      [{}, false],
      [declaration, true],
      [declaration.merge("private_messages" => :enforced), true],
      [declaration.except("private_messages"), false],
      [declaration.merge("private_messages" => :unenforced), false],
      [declaration.except("exit_paths"), false],
      [declaration.merge("exit_paths" => :unenforced), false],
      [declaration.merge("exit_paths" => :enforced), true],
      [
        declaration.merge(
          "topics" => :unenforced,
          "categories" => :unenforced,
          "tags" => :unenforced,
        ),
        true,
      ],
      [declaration.merge("unknown_core" => :untouched), false],
      [declaration.merge("future:messages" => :unenforced), true],
    ]
    expectations.each do |content, usable|
      aggregate_failures(content.inspect) do
        expect(DiscourseMcp.primitive_usable?(primitive(content))).to eq(usable)
      end
    end
  end

  it "limits plugin-kind applicability to its provider and explicitly touched identifiers" do
    prepare_registry
    registry.register_content_data_kind(
      "oracle:messages",
      provider: "oracle",
      touched_by: ["touched_tool"],
    )
    register_rule(affected_data_kinds: ["oracle:messages"])
    McpContentRule.create!(rule_kind: "oracle:rule", config: {})
    %w[core foreign oracle].each do |provider|
      expect(DiscourseMcp.primitive_usable?(primitive(declaration, provider:))).to eq(
        provider != "oracle",
      )
      expect(DiscourseMcp.primitive_usable?(primitive(:unbounded, provider:))).to eq(false)
    end
    expect(
      DiscourseMcp.primitive_usable?(primitive(declaration, identifier: "touched_tool")),
    ).to eq(false)
    expect(
      DiscourseMcp.primitive_usable?(
        primitive(declaration.merge("oracle:messages" => :enforced), provider: "oracle"),
      ),
    ).to eq(true)
    expect(
      DiscourseMcp.primitive_usable?(
        primitive(declaration.merge("oracle:messages" => :untouched), identifier: "touched_tool"),
      ),
    ).to eq(true)
    expect(
      DiscourseMcp.primitive_usable?(
        primitive(declaration.merge("oracle:messages" => :unenforced), provider: "oracle"),
      ),
    ).to eq(false)
    expect(DiscourseMcp.primitive_usable?(primitive(declaration.except("exit_paths")))).to eq(false)
  end

  it "unions affected kinds across simultaneous rules using the supplied policy snapshot" do
    prepare_registry
    registry.register_content_data_kind("oracle:messages", provider: "oracle")
    register_rule
    register_rule("oracle:second", affected_data_kinds: ["oracle:messages"])
    McpContentRule.create!(rule_kind: "oracle:rule", config: {})
    McpContentRule.create!(rule_kind: "oracle:second", config: {})
    policy = DiscourseMcp::ContentPolicy.load
    candidate = primitive(declaration, provider: "oracle")
    expect(DiscourseMcp.primitive_usable?(candidate, content_policy: policy)).to eq(false)
    McpContentRule.where(rule_kind: "oracle:second").delete_all
    expect(DiscourseMcp.primitive_usable?(candidate)).to eq(true)
    expect(DiscourseMcp.primitive_usable?(candidate, content_policy: policy)).to eq(false)
  end

  it "vetoes every declaration except none for unknown or unavailable stored rules" do
    prepare_registry
    available = true
    register_rule(availability: -> { available })
    rule = McpContentRule.create!(rule_kind: "oracle:rule", config: {})
    expect(DiscourseMcp::ContentPolicy.load).not_to be_orphaned
    available = false
    %w[oracle:rule removed:rule].each do |kind|
      rule.update!(rule_kind: kind)
      policy = DiscourseMcp::ContentPolicy.load
      expect(policy).to be_orphaned
      [
        nil,
        :unbounded,
        declaration,
        declaration.merge("oracle:messages" => :enforced),
      ].each do |content|
        expect(DiscourseMcp.primitive_usable?(primitive(content), content_policy: policy)).to eq(
          false,
        )
      end
      expect(DiscourseMcp.primitive_usable?(primitive(:none), content_policy: policy)).to eq(true)
    end
  end

  it "contains invalid stored configurations and compiler failures without disabling the policy" do
    prepare_registry
    received = []
    register_rule(
      config_contract: {
        type: "object",
        required: ["deny"],
        properties: {
          deny: {
            const: true,
          },
        },
        additionalProperties: false,
      },
      compile: ->(config) do
        received << config
        raise "oracle compiler failure"
      end,
    )
    rule = McpContentRule.create!(rule_kind: "oracle:rule", config: { "deny" => true })
    [{}, { "deny" => true }].each do |config|
      rule.update_columns(config:)
      policy = nil
      expect { policy = DiscourseMcp::ContentPolicy.load }.not_to raise_error
      expect(policy).to be_active
      expect(
        DiscourseMcp.primitive_usable?(
          primitive(declaration.merge("private_messages" => :unenforced)),
          content_policy: policy,
        ),
      ).to eq(false)
      expect(
        DiscourseMcp.primitive_usable?(
          primitive(declaration.merge("exit_paths" => :unenforced)),
          content_policy: policy,
        ),
      ).to eq(false)
    end
    expect(received).to include("deny" => true)
  end

  it "gives every core implementation an explicit bounded declaration naming all core kinds" do
    core = DiscourseMcp.registry.all.select { |registered| registered.provider == "core" }
    expect(core).to be_present
    core.each do |registered|
      aggregate_failures(registered.identifier) do
        expect(registered.implementation.const_defined?(:CONTENT, false)).to eq(true)
        expect(registered.content).to eq(
          primitive(registered.implementation.const_get(:CONTENT, false)).content,
        )
        expect(registered.content).not_to be_nil
        expect(registered.content).not_to eq(:unbounded)
        if registered.content.is_a?(Hash)
          expect(registered.content.keys).to contain_exactly(*core_kinds)
        end
      end
    end
  end
end
