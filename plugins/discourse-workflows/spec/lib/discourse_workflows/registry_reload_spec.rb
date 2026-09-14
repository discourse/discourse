# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  let(:loader) { Zeitwerk::Loader.new }
  let(:directory) { Dir.mktmpdir("workflow-reload") }
  let(:plugin) { Plugin::Instance.new }
  let(:handled) { [] }

  before do
    @registered_nodes = DiscoursePluginRegistry._raw_discourse_workflows_nodes.dup
    @credential_types = DiscoursePluginRegistry._raw_discourse_workflows_credential_types.dup
    @node_classes = DiscourseWorkflows::NodeType.registered_nodes.dup
    FileUtils.mkdir_p("#{directory}/workflow_reload_spec")
    write_helper("orange")
    File.write("#{directory}/workflow_reload_spec/node.rb", <<~RUBY)
      module WorkflowReloadSpec
        class Node < DiscourseWorkflows::NodeType
          include Helper

          description(
            name: "trigger:reload_test",
            version: "1.0",
            defaults: { color: Helper::COLOR },
            event: :workflow_reload_test,
            properties: {
              channel_id: {
                type: :integer,
                type_options: { load_options_method: "channels" },
              },
            },
          )

          def self.load_options_context(context)
            Helper.options
          end
        end
      end
    RUBY
    File.write("#{directory}/workflow_reload_spec/credential.rb", <<~RUBY)
      module WorkflowReloadSpec
        class Credential
          def self.identifier
            "reload_test"
          end

          def self.display_name
            Helper::COLOR
          end
        end
      end
    RUBY
    loader.push_dir(directory)
    loader.enable_reloading
    loader.setup
    DiscourseWorkflows.node_registration_ready = true
    plugin.register_discourse_workflows_node(WorkflowReloadSpec::Node)
    DiscoursePluginRegistry.register_discourse_workflows_credential_type(
      WorkflowReloadSpec::Credential.name,
      plugin,
    )
    described_class.reset_indexes!
    allow(DiscourseWorkflows::EventListener).to receive(:handle) do |klass, *args|
      handled << [klass, args]
    end
  end

  after do
    DiscourseEvent.all_off(:workflow_reload_test)
    DiscoursePluginRegistry._raw_discourse_workflows_nodes.replace(@registered_nodes)
    DiscoursePluginRegistry._raw_discourse_workflows_credential_types.replace(@credential_types)
    DiscourseWorkflows::NodeType.registered_nodes.replace(@node_classes)
    described_class.reset_indexes!
    loader.unload
    loader.unregister
    FileUtils.remove_entry(directory)
  end

  def write_helper(color)
    File.write("#{directory}/workflow_reload_spec/helper.rb", <<~RUBY)
      module WorkflowReloadSpec
        module Helper
          COLOR = #{color.inspect}

          def self.options
            [{ id: 1, name: COLOR }]
          end
        end
      end
    RUBY
  end

  it "lists current node metadata and dispatches once after repeated namespace reloads" do
    previous = described_class.find_node_type("trigger:reload_test")
    expect(previous.color).to eq("orange")

    %w[blue green].each do |color|
      write_helper(color)
      loader.reload
      current = described_class.find_node_type("trigger:reload_test")
      plugin.register_discourse_workflows_node(current)
      Plugin::Instance.new.register_discourse_workflows_node(current)

      expect(current).not_to equal(previous)
      expect(current).to equal(WorkflowReloadSpec::Node)
      serialized =
        DiscourseWorkflows::NodeTypeSerializer.new(
          identifier: "trigger:reload_test",
          available_versions: described_class.available_versions("trigger:reload_test"),
        ).to_h
      expect(serialized[:color]).to eq(color)
      expect(serialized[:metadata]).to eq("channels" => [{ id: 1, name: color }])

      DiscourseEvent.trigger(:workflow_reload_test, color)
      expect(handled.last).to eq([current, [color]])
      previous = current
    end

    expect(handled.size).to eq(2)
    entries =
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.select do |entry|
        entry[:value] == "WorkflowReloadSpec::Node"
      end
    expect(entries.map { |entry| entry[:plugin] }).to eq([plugin])

    allow(plugin).to receive(:enabled?).and_return(false)
    expect(described_class.find_node_type("trigger:reload_test")).to be_nil
    expect(
      described_class.find_node_type("trigger:reload_test", include_disabled_plugins: true),
    ).to equal(WorkflowReloadSpec::Node)
    DiscourseEvent.trigger(:workflow_reload_test, "disabled")
    expect(handled.size).to eq(2)
  end

  it "resolves the current credential class after warming the identifier cache" do
    previous = described_class.find_credential_type("reload_test")
    expect(previous.display_name).to eq("orange")

    write_helper("blue")
    loader.reload

    current = described_class.find_credential_type("reload_test")
    expect(current).not_to equal(previous)
    expect(current).to equal(WorkflowReloadSpec::Credential)
    expect(current.display_name).to eq("blue")
    expect(described_class.credential_types).to include(current)
  end
end
