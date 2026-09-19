# frozen_string_literal: true

describe AdminDashboardHighlights do
  before do
    freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0))
    Discourse.cache.clear
  end

  context "when solved is enabled" do
    before { SiteSetting.solved_enabled = true }

    it "omits the KPI when no category enables accepted answers" do
      Fabricate(:category)

      result = AdminDashboardHighlights.build(start_date: "2026-04-01", end_date: "2026-04-28")
      expect(result[:kpis].map { |k| k[:type] }).not_to include(:accepted_solutions)
    end

    it "includes the KPI when at least one category supports accepted answers" do
      category = Fabricate(:category)
      category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
      category.save!

      result = AdminDashboardHighlights.build(start_date: "2026-04-01", end_date: "2026-04-28")
      kpi = result[:kpis].find { |k| k[:type] == :accepted_solutions }

      expect(kpi).to be_present
      expect(kpi[:report_type]).to eq("accepted_solutions")
    end
  end

  context "when solved is disabled" do
    before { SiteSetting.solved_enabled = false }

    it "omits the KPI even if a category enables accepted answers" do
      category = Fabricate(:category)
      category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
      category.save!

      result = AdminDashboardHighlights.build(start_date: "2026-04-01", end_date: "2026-04-28")
      expect(result[:kpis].map { |k| k[:type] }).not_to include(:accepted_solutions)
    end
  end

  describe "accepted_solutions report prev_period facet" do
    fab!(:user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "populates prev_period when the facet is requested" do
      solved_topic =
        DiscourseSolved::SolvedTopic.create!(topic: topic, created_at: Time.zone.local(2026, 3, 15))

      DiscourseSolved::TopicAnswer.create!(
        solved_topic: solved_topic,
        post: post,
        accepter: user,
        created_at: Time.zone.local(2026, 3, 15),
      )

      report =
        Report.find(
          "accepted_solutions",
          start_date: Time.zone.local(2026, 4, 1),
          end_date: Time.zone.local(2026, 4, 28),
          facets: %i[prev_period],
        )

      expect(report.prev_period).to be >= 1
    end

    it "excludes deleted topics from prev_period" do
      solved_topic =
        DiscourseSolved::SolvedTopic.create!(topic: topic, created_at: Time.zone.local(2026, 3, 15))

      DiscourseSolved::TopicAnswer.create!(
        solved_topic: solved_topic,
        post: post,
        accepter: user,
        created_at: Time.zone.local(2026, 3, 15),
      )
      topic.trash!

      report =
        Report.find(
          "accepted_solutions",
          start_date: Time.zone.local(2026, 4, 1),
          end_date: Time.zone.local(2026, 4, 28),
          facets: %i[prev_period],
        )

      expect(report.prev_period.to_i).to eq(0)
    end

    it "excludes private message topics from prev_period" do
      pm = Fabricate(:private_message_topic)
      pm_post = Fabricate(:post, topic: pm)
      solved_topic =
        DiscourseSolved::SolvedTopic.create!(topic: pm, created_at: Time.zone.local(2026, 3, 15))

      DiscourseSolved::TopicAnswer.create!(
        solved_topic: solved_topic,
        post: pm_post,
        accepter: user,
        created_at: Time.zone.local(2026, 3, 15),
      )

      report =
        Report.find(
          "accepted_solutions",
          start_date: Time.zone.local(2026, 4, 1),
          end_date: Time.zone.local(2026, 4, 28),
          facets: %i[prev_period],
        )

      expect(report.prev_period.to_i).to eq(0)
    end
  end
end
