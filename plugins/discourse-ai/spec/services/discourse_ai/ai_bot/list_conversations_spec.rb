# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ListConversations do
  describe described_class::Contract, type: :model do
    it "requires page to be zero or greater" do
      contract = described_class.new(page: -1, per_page: 40)

      expect(contract).not_to be_valid
      expect(contract.errors[:page]).to be_present
    end

    it "requires per_page to be greater than zero" do
      contract = described_class.new(page: 0, per_page: 0)

      expect(contract).not_to be_valid
      expect(contract.errors[:per_page]).to be_present
    end

    it "limits per_page to 100" do
      contract = described_class.new(page: 0, per_page: 101)

      expect(contract).not_to be_valid
      expect(contract.errors[:per_page]).to be_present
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
    fab!(:starred_conversation) do
      Fabricate(
        :private_message_topic,
        user: current_user,
        recipient: bot_user,
        title: "Starred AI PM",
      )
    end
    fab!(:other_conversation) do
      Fabricate(:private_message_topic, user: other_user, recipient: bot_user, title: "Other AI PM")
    end
    fab!(:normal_pm) do
      Fabricate(:private_message_topic, user: current_user, recipient: other_user)
    end

    let(:params) { { page: 0, per_page: 40 } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:conversations) { result[:conversations].records }

    before do
      enable_current_plugin
      [conversation, starred_conversation, other_conversation].each do |topic|
        mark_ai_bot_pm(topic)
      end
      DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: starred_conversation)
      DiscourseAi::AiBot::ConversationStar.create!(user: other_user, topic: other_conversation)
    end

    it { is_expected.to run_successfully }

    it "returns current user's starred conversations before unstarred conversations" do
      expect(conversations.first).to eq(starred_conversation)
      expect(conversations).to include(conversation)
      expect(conversations).not_to include(normal_pm)
      expect(conversations).not_to include(other_conversation)
      expect(result[:meta]).to eq(page: 0, per_page: 40, has_more: false)
    end

    it "caps starred conversations" do
      extra_starred_conversations =
        2.times.map do |index|
          topic =
            Fabricate(
              :private_message_topic,
              user: current_user,
              recipient: bot_user,
              title: "Extra starred AI PM #{index}",
            )
          mark_ai_bot_pm(topic)
          DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: topic)
          topic
        end

      stub_const(DiscourseAi::AiBot::ConversationStar, :MAX_STARS_PER_USER, 2) do
        starred_records =
          conversations.select do |topic|
            DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: topic)
          end

        expect(starred_records.length).to eq(2)
        expect(starred_records).to all(be_in([starred_conversation, *extra_starred_conversations]))
      end
    end

    it "uses per_page plus one pagination instead of a total count" do
      Fabricate(:private_message_topic, user: current_user, recipient: bot_user).tap do |topic|
        mark_ai_bot_pm(topic)
      end

      result = described_class.call(params: { page: 0, per_page: 1 }, **dependencies)

      expect(result).to run_successfully
      expect(result[:conversations].records.length).to eq(2)
      expect(result[:conversations].records).to include(starred_conversation)
      expect(result[:meta]).to eq(page: 0, per_page: 1, has_more: true)
    end
  end

  def mark_ai_bot_pm(topic)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    topic.save!
  end
end
