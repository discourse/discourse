# frozen_string_literal: true

RSpec.describe DiscourseSolved::QuestionSchemaSerializer do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user, like_count: 2) }

  context "without an accepted answer" do
    subject(:json) { described_class.new(topic, root: false).serializable_hash.deep_stringify_keys }

    it "includes the Question @type" do
      expect(json["@type"]).to eq("Question")
    end

    it "serializes the topic attributes" do
      expect(json["name"]).to eq(topic.title)
      expect(json["text"]).to be_present
      expect(json["upvoteCount"]).to eq(2)
      expect(json["answerCount"]).to eq(0)
      expect(json["datePublished"]).to eq(topic.created_at)
    end

    it "serializes the author" do
      expect(json["author"]).to eq(
        { "@type" => "Person", "name" => user.username, "url" => user.full_url },
      )
    end

    it "does not include acceptedAnswer" do
      expect(json).not_to have_key("acceptedAnswer")
    end
  end

  context "with an accepted answer" do
    fab!(:answer_user, :user)
    fab!(:answer_post) { Fabricate(:post, topic: topic, user: answer_user, like_count: 7) }

    subject(:json) do
      described_class
        .new(topic, root: false, accepted_answer: answer_post)
        .serializable_hash
        .deep_stringify_keys
    end

    it "sets answerCount to 1" do
      expect(json["answerCount"]).to eq(1)
    end

    it "includes the accepted answer" do
      accepted = json["acceptedAnswer"]
      expect(accepted["@type"]).to eq("Answer")
      expect(accepted["upvoteCount"]).to eq(7)
      expect(accepted["author"]).to eq(
        { "@type" => "Person", "name" => answer_user.username, "url" => answer_user.full_url },
      )
    end
  end
end
