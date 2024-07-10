# frozen_string_literal: true

describe "CloseTopic" do
  fab!(:user)
  fab!(:category) { Fabricate(:category, user: user) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scripts::CLOSE_TOPIC) }

  before { automation.upsert_field!("topic", "text", { value: topic.id }, target: "script") }

  context "with default params" do
    it "works" do
      expect(topic.closed).to be_falsey

      automation.trigger!
      topic.reload

      expect(topic.closed).to be_truthy

      closing_post = topic.posts.where(action_code: "closed.enabled").last
      expect(closing_post.raw).to eq("")
      expect(closing_post.user_id).to eq(-1)
    end
  end

  context "with message" do
    before do
      automation.upsert_field!(
        "message",
        "text",
        { value: "dingity dongity dong, this topic is closed!" },
      )
    end

    it "works" do
      expect(topic.closed).to be_falsey

      automation.trigger!
      topic.reload

      expect(topic.closed).to be_truthy

      closing_post = topic.posts.where(action_code: "closed.enabled").last
      expect(closing_post.raw).to eq("dingity dongity dong, this topic is closed!")
    end
  end

  # NOTE: this is only possible because we skip validations for now.
  # As soon as discourse-automation supports proper error handling and validations take place again,
  # this test should be removed.
  context "with very short message" do
    before { automation.upsert_field!("message", "text", { value: "bye" }) }

    it "closes the topic" do
      expect(topic.closed).to be_falsey

      automation.trigger!
      topic.reload

      expect(topic.closed).to be_truthy

      closing_post = topic.posts.where(action_code: "closed.enabled").last
      expect(closing_post.raw).to eq("bye")
    end
  end

  context "with a specific user" do
    fab!(:specific_user) { Fabricate(:user, admin: true) }

    before { automation.upsert_field!("user", "user", { value: specific_user.username }) }

    it "closes the topic" do
      expect(topic.closed).to be_falsey

      automation.trigger!
      topic.reload

      expect(topic.closed).to be_truthy
      closing_post = topic.posts.where(action_code: "closed.enabled").last
      expect(closing_post.user_id).to eq(specific_user.id)
    end
  end
end
