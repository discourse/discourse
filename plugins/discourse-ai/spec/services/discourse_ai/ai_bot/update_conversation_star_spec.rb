# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::UpdateConversationStar do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }

    it "requires starred to be true or false" do
      expect(described_class.new(topic_id: 1, starred: true)).to be_valid
      expect(described_class.new(topic_id: 1, starred: false)).to be_valid
      expect(described_class.new(topic_id: 1, starred: nil)).not_to be_valid
    end

    it "accepts boolean strings" do
      expect(described_class.new(topic_id: 1, starred: "true")).to be_valid
      expect(described_class.new(topic_id: 1, starred: "false")).to be_valid
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params, **dependencies) }

    fab!(:current_user, :user)
    fab!(:other_user, :user)
    fab!(:bot_user, :user)
    fab!(:conversation) do
      Fabricate(:private_message_topic, user: current_user, recipient: bot_user, title: "AI PM")
    end
    fab!(:other_conversation) do
      Fabricate(:private_message_topic, user: other_user, recipient: bot_user, title: "Other AI PM")
    end
    fab!(:regular_topic, :topic)
    fab!(:normal_pm) do
      Fabricate(:private_message_topic, user: current_user, recipient: other_user)
    end
    fab!(:invisible_pm) { Fabricate(:private_message_topic, user: other_user, recipient: bot_user) }

    let(:params) { { topic_id: conversation.id, starred: true, user_id: other_user.id } }
    let(:dependencies) { { guardian: current_user.guardian } }

    before do
      enable_current_plugin
      SiteSetting.enable_ai_bot_starred_conversations = true
      mark_ai_bot_pm(conversation)
      mark_ai_bot_pm(other_conversation)
      mark_ai_bot_pm(invisible_pm)
    end

    context "when the contract is invalid" do
      context "with a missing topic_id" do
        let(:params) { { starred: true } }

        it { is_expected.to fail_a_contract }
      end

      context "with a missing starred value" do
        let(:params) { { topic_id: conversation.id } }

        it { is_expected.to fail_a_contract }
      end
    end

    context "when the upcoming change is disabled" do
      before { SiteSetting.enable_ai_bot_starred_conversations = false }

      it { is_expected.to fail_a_policy(:feature_enabled) }

      it "does not create a star" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when the conversation cannot be found" do
      let(:params) { { topic_id: 99_999_999, starred: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic is a regular public topic" do
      let(:params) { { topic_id: regular_topic.id, starred: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }

      it "does not create a star" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when the topic is a non-AI PM" do
      let(:params) { { topic_id: normal_pm.id, starred: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }

      it "does not create a star" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when the AI bot PM belongs to another user" do
      let(:params) { { topic_id: other_conversation.id, starred: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }

      it "does not create a star" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when the user cannot see the private message" do
      let(:params) { { topic_id: invisible_pm.id, starred: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }

      it "does not create a star" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when starring the conversation" do
      it { is_expected.to run_successfully }

      it "fails when the user has reached the star limit" do
        stub_const(DiscourseAi::AiBot::ConversationStar, :MAX_STARS_PER_USER, 1) do
          DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: Fabricate(:topic))

          expect(result).to fail_a_policy(:user_can_star_more_conversations)
        end
      end

      it "creates a star for the current user and ignores supplied user_id" do
        expect { result }.to change { DiscourseAi::AiBot::ConversationStar.count }.by(1)

        expect(
          DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: conversation),
        ).to eq(true)
        expect(
          DiscourseAi::AiBot::ConversationStar.exists?(user: other_user, topic: conversation),
        ).to eq(false)
      end

      it "is idempotent" do
        described_class.call(params: params, **dependencies)

        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end

    context "when unstarring the conversation" do
      let(:params) { { topic_id: conversation.id, starred: false } }

      it { is_expected.to run_successfully }

      it "deletes only the current user's star" do
        DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: conversation)
        DiscourseAi::AiBot::ConversationStar.create!(user: other_user, topic: conversation)

        expect { result }.to change {
          DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: conversation)
        }.from(true).to(false)
        expect(
          DiscourseAi::AiBot::ConversationStar.exists?(user: other_user, topic: conversation),
        ).to eq(true)
      end

      it "is idempotent when no row exists" do
        expect { result }.not_to change { DiscourseAi::AiBot::ConversationStar.count }
      end
    end
  end

  def mark_ai_bot_pm(topic)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    topic.save!
  end
end
