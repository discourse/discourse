# frozen_string_literal: true

RSpec.describe DiscourseSolved::BuildSchemaMarkup do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:first_post) { Fabricate(:post, topic: topic, user: user, like_count: 1) }

    let(:guardian) { Guardian.new(user) }
    let(:params) { { topic_id: topic.id } }
    let(:dependencies) { { guardian: guardian } }

    before { SiteSetting.allow_solved_on_all_topics = true }

    context "when topic_id is nil" do
      let(:params) { { topic_id: nil } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when schema markup is disabled" do
      before { SiteSetting.solved_add_schema_markup = "never" }

      it { is_expected.to fail_a_policy(:schema_markup_enabled) }
    end

    context "when accepted answers are not allowed on the topic" do
      before { SiteSetting.allow_solved_on_all_topics = false }

      it { is_expected.to fail_a_policy(:accepted_answers_allowed) }
    end

    context "when topic has no first post" do
      before { first_post.destroy! }

      it { is_expected.to fail_to_find_a_model(:first_post) }
    end

    context "when setting is 'answered only' and there is no accepted answer" do
      before { SiteSetting.solved_add_schema_markup = "answered only" }

      it { is_expected.to fail_a_policy(:has_answer_if_required) }
    end

    context "when setting is 'always' and there is no accepted answer" do
      before { SiteSetting.solved_add_schema_markup = "always" }

      it { is_expected.to run_successfully }

      it "builds QAPage markup without an answer" do
        html = result[:html]
        expect(html).to include("application/ld+json")
        expect(html).to include('"@type":"QAPage"')
        expect(html).to include('"answerCount":0')
        expect(html).not_to include('"acceptedAnswer"')
      end
    end

    context "when there is an accepted answer" do
      fab!(:answer_user, :user)
      fab!(:answer_post) { Fabricate(:post, topic: topic, user: answer_user, like_count: 3) }

      before do
        SiteSetting.solved_add_schema_markup = "always"
        Fabricate(:solved_topic, topic: topic, answer_post: answer_post)
      end

      it { is_expected.to run_successfully }

      it "builds QAPage markup with the accepted answer" do
        html = result[:html]
        expect(html).to include('"@type":"QAPage"')
        expect(html).to include('"answerCount":1')
        expect(html).to include('"acceptedAnswer"')
        expect(html).to include('"@type":"Answer"')
        expect(html).to include(answer_user.username)
      end
    end
  end

  describe ".html_for" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:first_post) { Fabricate(:post, topic: topic, user: user, like_count: 1) }

    let(:guardian) { Guardian.new(user) }

    before do
      SiteSetting.allow_solved_on_all_topics = true
      SiteSetting.solved_add_schema_markup = "always"
    end

    it "returns the schema markup HTML" do
      html = described_class.html_for(topic_id: topic.id, guardian: guardian)
      expect(html).to include('"@type":"QAPage"')
    end

    it "returns an empty string when the service exits early" do
      html = described_class.html_for(topic_id: nil, guardian: guardian)
      expect(html).to eq("")
    end
  end
end
