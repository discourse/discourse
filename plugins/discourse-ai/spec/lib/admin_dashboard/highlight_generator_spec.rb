# frozen_string_literal: true

RSpec.describe DiscourseAi::AdminDashboard::HighlightGenerator do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_admin_dashboard_enabled = true

    kpis = [
      {
        type: :new_signups,
        value: 1100,
        previous_value: 980,
        percent_change: 12.0,
        report_type: "signups",
        report_query: {
        },
      },
    ]
    allow(AdminDashboardHighlights).to receive(:build).and_return({ kpis: kpis })

    agent_id = SiteSetting.ai_admin_dashboard_highlights_agent.to_i
    AiAgent.find_by(id: agent_id) ||
      Fabricate(
        :ai_agent,
        id: agent_id,
        name: "Admin Dashboard Highlights #{SecureRandom.hex(4)}",
        description: "Writes admin dashboard highlights",
        allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
        enabled: true,
        system: true,
      )
  end

  it "hands the grounded facts to the agent and returns its highlight" do
    response = { highlight: "Your community grew to 1,100 new members." }.to_json

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
        described_class.generate(
          start_date: "2026-05-01",
          end_date: "2026-06-01",
          period: "last_30_days",
        )
      end

    expect(result).to eq("Your community grew to 1,100 new members.")
  end

  it "caches the result so the LLM is only invoked once per period" do
    response = { highlight: "Cached highlight." }.to_json

    DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
      described_class.generate(
        start_date: "2026-05-01",
        end_date: "2026-06-01",
        period: "last_30_days",
      )
    end

    again =
      described_class.generate(
        start_date: "2026-05-01",
        end_date: "2026-06-01",
        period: "last_30_days",
      )

    expect(again).to eq("Cached highlight.")
  end

  it "returns an empty string when there are no metrics" do
    allow(AdminDashboardHighlights).to receive(:build).and_return({ kpis: [] })

    expect(described_class.generate(start_date: "2026-05-01", end_date: "2026-06-01")).to eq("")
  end

  it "returns an empty string when admin dashboard highlights are disabled" do
    SiteSetting.ai_admin_dashboard_enabled = false

    expect(described_class.generate(start_date: "2026-05-01", end_date: "2026-06-01")).to eq("")
  end

  describe "the grounded prompt" do
    def message_for(start_date, end_date)
      generator = described_class.new(start_date: start_date, end_date: end_date)
      facts =
        DiscourseAi::AdminDashboard::AdminDashboardFacts.compute(
          start_date: start_date,
          end_date: end_date,
        )
      generator.send(:user_message, facts)
    end

    it "includes the metrics and hard grounding rules" do
      message = message_for("2026-05-01", "2026-06-01")

      expect(message).to include("new sign-ups: 1100")
      expect(message).to match(/Use ONLY the numbers and facts listed above/)
      expect(message).to match(/Do not invent sources, dates, causes, or numbers/)
      expect(message).to match(/Do not overstate causality/)
      expect(message).to match(/Do not say traffic "translated"/)
      expect(message).to match(/Avoid report phrases/)
      expect(message).to match(/what to inspect next/)
    end

    it "says nothing stood out when no signal clears its threshold" do
      message = message_for("2026-05-01", "2026-06-01")

      expect(message).to include("Nothing else stood out.")
    end

    it "surfaces a real signal as a fact the agent can cite" do
      Fabricate.times(5, :post) # 5 topics with no replies

      message = message_for(1.day.ago.to_date.to_s, Date.current.to_s)

      expect(message).to match(/new topics received no reply/)
    end

    it "asks the agent to write in the requesting user's language" do
      message = I18n.with_locale(:fr) { message_for("2026-05-01", "2026-06-01") }

      expect(message).to include("Write the highlight in French.")
    end

    it "adds no language directive for English" do
      message = I18n.with_locale(:en) { message_for("2026-05-01", "2026-06-01") }

      expect(message).not_to include("Write the highlight in")
    end
  end
end
