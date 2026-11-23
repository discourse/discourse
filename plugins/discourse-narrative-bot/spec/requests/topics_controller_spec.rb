# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:user)
  fab!(:moderator)
  fab!(:discobot_user) { DiscourseNarrativeBot::Base.new.discobot_user }
  fab!(:topic) { Fabricate(:system_message_topic, user: discobot_user, recipient: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: discobot_user) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: user) }
  fab!(:category)

  before { SiteSetting.discourse_narrative_bot_enabled = true }

  describe "#convert_topic" do
    it "denies conversion of a tutorial PM by a non-participant moderator" do
      sign_in(moderator)

      put "/t/#{topic.id}/convert-topic/public.json", params: { category_id: category.id }

      expect(response).to be_forbidden
      expect(topic.reload.archetype).to eq(Archetype.private_message)

      sign_out
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(404)
      expect(response.body).not_to include(reply.raw)
    end
  end
end
