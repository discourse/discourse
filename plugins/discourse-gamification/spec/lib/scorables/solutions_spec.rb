# frozen_string_literal: true

RSpec.describe DiscourseGamification::Solutions do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:question_user) { Fabricate(:user) }
  fab!(:answer_user) { Fabricate(:user) }
  fab!(:answer_post) { Fabricate(:post, topic: topic, user: answer_user) }

  before { SiteSetting.solution_score_value = 5 }

  it "is enabled when score value is positive" do
    expect(described_class).to be_enabled

    SiteSetting.solution_score_value = 0
    expect(described_class).not_to be_enabled
  end

  describe "scoring query" do
    def query_results
      DB.query(described_class.query, since: 2.days.ago)
    end

    it "scores accepted answers correctly" do
      freeze_time DateTime.parse("2024-01-01 12:00")

      DiscourseSolved.accept_answer!(answer_post, Discourse.system_user)

      expect(query_results).to contain_exactly(
        have_attributes(user_id: answer_user.id, date: Time.current.beginning_of_day, points: 5.0),
      )

      DiscourseSolved.unaccept_answer!(answer_post, topic:)
      expect(query_results).to be_empty
    end

    it "doesn't score self-accepted answers" do
      topic.update!(user: answer_user)
      DiscourseSolved.accept_answer!(answer_post, Discourse.system_user)

      expect(query_results).to be_empty
    end
  end

  it "is disabled when solved plugin is disabled" do
    SiteSetting.solved_enabled = false
    expect(described_class).not_to be_enabled

    SiteSetting.solved_enabled = true
    SiteSetting.solution_score_value = 0
    expect(described_class).not_to be_enabled

    SiteSetting.solution_score_value = 1
    expect(described_class).to be_enabled
  end
end
