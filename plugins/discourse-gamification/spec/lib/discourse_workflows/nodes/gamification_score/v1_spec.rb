# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::GamificationScore::V1 do
  fab!(:user)

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }

  after { sandbox.dispose }

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.discourse_gamification_enabled = true
  end

  def execute_node(configuration:, item: { "json" => {} })
    action = described_class.new(parameters: configuration)
    input_items = [item]
    resolver =
      DiscourseWorkflows::ExpressionResolver.new(
        { "$json" => item.fetch("json") { {} } },
        sandbox: sandbox,
      )
    exec_ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: input_items,
        user: Discourse.system_user,
        resolver: resolver,
        parameters: configuration,
        property_schema: described_class.property_schema,
        node_context: {
        },
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    it "creates a score event for the user", :aggregate_failures do
      config = {
        "username" => user.username,
        "points" => 10,
        "description" => "Helped in the support forum",
      }

      result = nil
      expect { result = execute_node(configuration: config) }.to change {
        DiscourseGamification::GamificationScoreEvent.count
      }.by(1)

      event = DiscourseGamification::GamificationScoreEvent.last
      expect(event.user_id).to eq(user.id)
      expect(event.points).to eq(10)
      expect(event.date).to eq(Time.zone.today)
      expect(event.description).to eq("Helped in the support forum")

      expect(result["score_event_id"]).to eq(event.id)
      expect(result["user_id"]).to eq(user.id)
      expect(result["username"]).to eq(user.username)
      expect(result["points"]).to eq(10)
      expect(result["date"]).to eq(Time.zone.today.to_s)
      expect(result).to match_node_output_schema(described_class)
    end

    it "accepts negative points to deduct score" do
      config = { "username" => user.username, "points" => -5 }

      execute_node(configuration: config)

      expect(DiscourseGamification::GamificationScoreEvent.last.points).to eq(-5)
    end

    it "uses the provided date" do
      config = { "username" => user.username, "points" => 3, "date" => "2026-01-15" }

      result = execute_node(configuration: config)

      expect(DiscourseGamification::GamificationScoreEvent.last.date).to eq(Date.new(2026, 1, 15))
      expect(result["date"]).to eq("2026-01-15")
    end

    it "stores a nil description when blank" do
      config = { "username" => user.username, "points" => 3, "description" => "" }

      execute_node(configuration: config)

      expect(DiscourseGamification::GamificationScoreEvent.last.description).to be_nil
    end

    it "raises when the user does not exist" do
      config = { "username" => "nonexistent", "points" => 10 }

      expect { execute_node(configuration: config) }.to raise_error(DiscourseWorkflows::NodeError)
    end

    it "raises when points is zero" do
      config = { "username" => user.username, "points" => 0 }

      expect { execute_node(configuration: config) }.to raise_error(DiscourseWorkflows::NodeError)
    end

    it "raises when points is not a number" do
      config = { "username" => user.username, "points" => "lots" }

      expect { execute_node(configuration: config) }.to raise_error(DiscourseWorkflows::NodeError)
    end

    it "raises when the date is invalid" do
      config = { "username" => user.username, "points" => 5, "date" => "not-a-date" }

      expect { execute_node(configuration: config) }.to raise_error(DiscourseWorkflows::NodeError)
    end
  end
end
