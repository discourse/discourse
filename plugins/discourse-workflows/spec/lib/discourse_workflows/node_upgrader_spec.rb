# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeUpgrader do
  let(:note_key) { "discourse_workflows.admin_assistant.not_allowed" }

  before do
    note_key = self.note_key
    register_versioned_workflow_nodes(
      "action:upgrader_test",
      v1_upgrade: ->(parameters) do
        case parameters["operation"]
        when "log"
          { type: "action:log", parameters: { "message" => parameters["name"] }, notes: [note_key] }
        when "rename"
          { type: "action:upgrader_test", parameters: { "title" => parameters["name"] } }
        when "branch"
          { type: "condition:if", parameters: {} }
        when "deprecated"
          { type: "action:topic", version: "1.0", parameters: {} }
        end
      end,
    )
  end

  def saved_node(name, parameters)
    {
      "id" => "#{name}-id",
      "type" => "action:upgrader_test",
      "typeVersion" => "1.0",
      "name" => name,
      "position" => {
        "x" => 10,
        "y" => 20,
      },
      "parameters" => parameters,
      "credentials" => {
      },
      "onError" => "continueRegularOutput",
    }
  end

  describe ".call" do
    it "upgrades deprecated nodes and keeps everything that identifies them", :aggregate_failures do
      log = saved_node("Log", { "operation" => "log", "name" => "Hello" })
      rename = saved_node("Rename", { "operation" => "rename", "name" => "New title" })
      current = saved_node("Current", { "title" => "Kept" }).merge("typeVersion" => "2.0")

      result = described_class.call([log, rename, current])

      expect(result.nodes).to eq(
        [
          log.merge(
            "type" => "action:log",
            "typeVersion" => DiscourseWorkflows::Registry.latest_version("action:log"),
            "parameters" => {
              "message" => "Hello",
            },
          ),
          rename.merge("typeVersion" => "2.0", "parameters" => { "title" => "New title" }),
          current,
        ],
      )
      expect(result.upgrades).to contain_exactly(
        described_class::Upgrade.new(
          name: "Log",
          from: {
            type: "action:upgrader_test",
            version: "1.0",
          },
          to: {
            type: "action:log",
            version: DiscourseWorkflows::Registry.latest_version("action:log"),
          },
          notes: [I18n.t(note_key)],
        ),
        described_class::Upgrade.new(
          name: "Rename",
          from: {
            type: "action:upgrader_test",
            version: "1.0",
          },
          to: {
            type: "action:upgrader_test",
            version: "2.0",
          },
          notes: [],
        ),
      )
      expect(result.skipped).to be_empty
    end

    it "moves a superseded version to its newer version with the same parameters" do
      register_versioned_workflow_nodes(
        "action:superseded_upgrader_test",
        v1_deprecation: {
          superseded_by: "2.0",
        },
      )
      node =
        saved_node("Superseded", { "title" => "Kept" }).merge(
          "type" => "action:superseded_upgrader_test",
        )

      result = described_class.call([node])

      expect(result.nodes).to eq([node.merge("typeVersion" => "2.0")])
    end

    it "leaves nodes it can't upgrade untouched" do
      unknown = saved_node("Unknown", { "operation" => "unknown" })
      branch = saved_node("Branch", { "operation" => "branch" })
      deprecated = saved_node("Deprecated", { "operation" => "deprecated" })

      result = described_class.call([unknown, branch, deprecated])

      expect(result).to have_attributes(
        nodes: [unknown, branch, deprecated],
        upgrades: [],
        skipped: %w[Unknown Branch Deprecated],
      )
    end
  end
end
