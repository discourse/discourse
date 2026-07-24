# frozen_string_literal: true

RSpec.describe DiscourseSolved::TopicAnswer do
  fab!(:topic, :topic_with_op)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:solved_topic) { Fabricate(:solved_topic, topic:) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe "Associations" do
    it { is_expected.to belong_to(:solved_topic) }
    it { is_expected.to belong_to(:post) }
    it { is_expected.to belong_to(:accepter) }
  end

  describe "Validations" do
    it { is_expected.to validate_presence_of(:solved_topic_id) }
    it { is_expected.to validate_presence_of(:answer_post_id) }
    it { is_expected.to validate_presence_of(:accepter_user_id) }
  end
end
