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
    agent =
      AiAgent.find_by(id: agent_id) ||
        Fabricate(
          :ai_agent,
          id: agent_id,
          name: "Admin Dashboard Highlights #{SecureRandom.hex(4)}",
          description: "Writes admin dashboard highlights",
          allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
          system: true,
        )
    agent.update!(enabled: true)
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

  it "uses category settings in the cache key" do
    category = Fabricate(:category)
    responses = [
      { highlight: "Highlight before category ids." }.to_json,
      { highlight: "Highlight after category ids." }.to_json,
    ]

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        described_class.generate(
          start_date: "2026-05-01",
          end_date: "2026-06-01",
          period: "last_30_days",
        )

        SiteSetting.ai_admin_dashboard_highlights_category_scope = "include"
        SiteSetting.ai_admin_dashboard_highlights_categories = category.id.to_s

        described_class.generate(
          start_date: "2026-05-01",
          end_date: "2026-06-01",
          period: "last_30_days",
        )
      end

    expect(result).to eq("Highlight after category ids.")
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
      expect(message).to include("Period length: 32 days")
      expect(message).to include("Community-owner lenses:")
      expect(message).to include("Acquisition and discovery: new sign-ups: 1100")
      expect(message).to match(/Use ONLY the numbers and facts listed above/)
      expect(message).to match(/Do not mention a metric whose value is "not available"/)
      expect(message).to match(/Do not invent sources, dates, causes, or numbers/)
      expect(message).to match(/Never say "a specific external referrer"/)
      expect(message).to match(/Do not overstate causality/)
      expect(message).to match(/Do not say traffic "translated"/)
      expect(message).to match(/"did not stem"/)
      expect(message).to match(/state only its date, size, and listed referrer/)
      expect(message).to match(/Avoid report phrases/)
      expect(message).to match(/next inspection areas/)
    end

    it "keeps unavailable metrics out of owner lenses" do
      allow(AdminDashboardHighlights).to receive(:build).and_return(
        {
          kpis: [
            {
              type: :new_signups,
              value: nil,
              previous_value: 10,
              percent_change: nil,
              report_type: "signups",
              report_query: {
              },
            },
          ],
        },
      )

      message = message_for("2026-05-01", "2026-06-01")

      expect(message).to include("new sign-ups: not available")
      expect(message).not_to include("Acquisition and discovery: new sign-ups")
    end

    it "says nothing stood out when no signal clears its threshold" do
      message = message_for("2026-05-01", "2026-06-01")

      expect(message).to include("Nothing else stood out.")
    end

    it "surfaces a real signal as a fact the agent can cite" do
      user = Fabricate(:user)
      now = Time.zone.now
      DB.exec(
        <<~SQL,
          INSERT INTO topics (
            title, fancy_title, created_at, updated_at, bumped_at, last_posted_at, posts_count,
            user_id, last_post_user_id, category_id, visible, archetype, highest_post_number
          )
          SELECT
            'Unanswered topic ' || topic_number,
            'Unanswered topic ' || topic_number,
            :now,
            :now,
            :now,
            :now,
            1,
            :user_id,
            :user_id,
            :category_id,
            true,
            'regular',
            1
          FROM generate_series(1, 5) AS topic_number
        SQL
        now: now,
        user_id: user.id,
        category_id: SiteSetting.uncategorized_category_id,
      )

      message = message_for(1.day.ago.to_date.to_s, Date.current.to_s)

      expect(message).to match(/new member-created topics received no reply/)
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
