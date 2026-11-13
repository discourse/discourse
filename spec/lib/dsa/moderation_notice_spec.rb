# frozen_string_literal: true

RSpec.describe Dsa::ModerationNotice do
  describe "#enqueue" do
    fab!(:user)

    let(:rule) { { "ground" => "Be respectful", "explanation" => "No personal attacks." } }
    let(:options) do
      {
        url: "/t/example/123/2",
        flag_reason: "Original reason.",
        edit_delay: 5,
        flagged_post_raw_content: "Original post.",
        flagged_post_response_raw_content: "Reply.",
      }
    end

    it "adds the rule in the recipient's current locale without changing the existing body or subject" do
      enable_dsa_reporting(community_rules: [rule])
      SiteSetting.allow_user_locale = true
      TranslationOverride.upsert!(
        :fr,
        "system_messages.moderation_reason",
        "Plus précisément : **%{ground}**. %{explanation}",
      )

      described_class.new(community_rule: rule).enqueue(
        user_id: user.id,
        message_type: "post_hidden",
        message_options: options,
      )
      user.update!(locale: "fr")
      baseline = SystemMessage.create(user, :post_hidden, options)
      args = Jobs::SendDsaModerationNotice.jobs.sole["args"].first
      Jobs::SendDsaModerationNotice.new.perform(args)

      notice = Post.last
      expected_reason =
        "#{options[:flag_reason]}\n\nPlus précisément : **#{rule["ground"]}**. #{rule["explanation"]}"
      expect(notice.raw).to eq(baseline.raw.sub(options[:flag_reason], expected_reason))
      expect(notice.topic.title).to eq(baseline.topic.title)
    end

    it "preserves every existing notice when DSA is disabled or no rule is selected" do
      %w[
        post_hidden
        post_hidden_again
        flags_agreed_and_post_deleted
        flags_agreed_and_post_deleted_for_responders
      ].each do |type|
        Jobs::SendSystemMessage.clear
        baseline = SystemMessage.create(user, type, options)
        enable_dsa_reporting(community_rules: [rule])
        described_class.new(community_rule: nil).enqueue(
          user_id: user.id,
          message_type: type,
          message_options: options,
        )
        Jobs::SendSystemMessage.new.perform(Jobs::SendSystemMessage.jobs.sole["args"].first)
        unclassified = Post.last

        SiteSetting.dsa_reporting_enabled = false
        Jobs::SendSystemMessage.clear
        described_class.new(community_rule: rule).enqueue(
          user_id: user.id,
          message_type: type,
          message_options: options,
        )
        Jobs::SendSystemMessage.new.perform(Jobs::SendSystemMessage.jobs.sole["args"].first)
        disabled = Post.last

        expect(unclassified.raw).to eq(baseline.raw)
        expect(disabled.raw).to eq(baseline.raw)
        expect(unclassified.topic.title).to eq(baseline.topic.title)
        expect(disabled.topic.title).to eq(baseline.topic.title)
        expect(Jobs::SendDsaModerationNotice.jobs).to be_empty
      end
    end

    it "uses the existing copy if DSA is disabled before delivery" do
      enable_dsa_reporting(community_rules: [rule])
      baseline = SystemMessage.create(user, :post_hidden, options)
      described_class.new(community_rule: rule).enqueue(
        user_id: user.id,
        message_type: "post_hidden",
        message_options: options,
      )
      SiteSetting.dsa_reporting_enabled = false

      Jobs::SendDsaModerationNotice.new.perform(
        Jobs::SendDsaModerationNotice.jobs.sole["args"].first,
      )

      expect(Post.last.raw).to eq(baseline.raw)
    end
  end
end
