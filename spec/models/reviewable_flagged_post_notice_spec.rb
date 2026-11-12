# frozen_string_literal: true

RSpec.describe ReviewableFlaggedPost do
  describe "#perform" do
    fab!(:moderator)
    fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:post)

    let(:rule) do
      {
        "ground" => "Community Guidelines: Be agreeable",
        "explanation" => "Personal attacks are not allowed.",
      }
    end
    let(:classification) do
      { community_rule: rule, category: DsaStatementOfRecord::TERMS_VIOLATION_CATEGORY }
    end
    let(:reason) do
      "More specifically, your post violated the following community guideline: **#{rule["ground"]}**. #{rule["explanation"]}"
    end

    before do
      enable_dsa_reporting(community_rules: [rule])
      SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
    end

    it "includes the selected rule in the existing notice for agree_and_hide" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :agree_and_hide, dsa_classification: classification)

      message_args = Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys
      Jobs::SendSystemMessage.new.execute(message_args)

      notice = Post.last
      expect(notice.topic.allowed_users).to include(post.user)
      expect(notice.raw).to include(reason, "To appeal this decision, contact appeals@example.com")
      expect(notice.raw.index(reason)).to be < notice.raw.index("This post was")
    end

    it "includes the selected rule in the existing notice for delete_and_agree" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :delete_and_agree, dsa_classification: classification)

      message_args = Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys
      Jobs::SendSystemMessage.new.execute(message_args)

      notice = Post.last
      expect(notice.topic.allowed_users).to include(post.user)
      expect(notice.raw).to include(reason, "To appeal this decision, contact appeals@example.com")
      expect(notice.raw.index(reason)).to be < notice.raw.index("This post was")
    end

    it "includes the selected rule in the existing notice for delete_and_ignore" do
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :delete_and_ignore, dsa_classification: classification)

      message_args = Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys
      Jobs::SendSystemMessage.new.execute(message_args)

      notice = Post.last
      expect(notice.topic.allowed_users).to include(post.user)
      expect(notice.raw).to include(reason, "To appeal this decision, contact appeals@example.com")
      expect(notice.raw.index(reason)).to be < notice.raw.index("This post was")
    end

    it "includes the selected rule when hiding an edited post again" do
      post.update!(hidden_at: 1.day.ago)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :agree_and_hide, dsa_classification: classification)

      message_args = Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys
      expect(message_args[:message_type]).to eq("post_hidden_again")
      Jobs::SendSystemMessage.new.execute(message_args)
      expect(Post.last.raw).to include(reason)
    end

    it "explains the parent's violation to responders for delete_and_agree_replies" do
      reply =
        PostCreator.create!(
          Fabricate(:user),
          topic_id: post.topic_id,
          reply_to_post_number: post.post_number,
          raw: "Please keep the discussion respectful.",
        )
      post.reload
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      SiteSetting.notify_users_after_responses_deleted_on_flagged_post = true
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :delete_and_agree_replies, dsa_classification: classification)

      notices = Jobs::SendSystemMessage.jobs.map { |job| job["args"].first.deep_symbolize_keys }
      expect(notices.size).to eq(2)
      parent_notice = notices.find { |notice| notice[:user_id] == post.user_id }
      Jobs::SendSystemMessage.new.execute(parent_notice)
      expect(Post.last.raw).to include(reason)

      reply_notice = notices.find { |notice| notice[:user_id] == reply.user_id }
      Jobs::SendSystemMessage.new.execute(reply_notice)
      expect(Post.last.raw).to include(
        "More specifically, the post you replied to violated the following community guideline: **#{rule["ground"]}**. #{rule["explanation"]}",
      )
      expect(Post.last.raw).not_to include(reason)
    end

    it "explains the parent's violation to responders for delete_and_ignore_replies" do
      reply =
        PostCreator.create!(
          Fabricate(:user),
          topic_id: post.topic_id,
          reply_to_post_number: post.post_number,
          raw: "Please keep the discussion respectful.",
        )
      post.reload
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      SiteSetting.notify_users_after_responses_deleted_on_flagged_post = true
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :delete_and_ignore_replies, dsa_classification: classification)

      notices = Jobs::SendSystemMessage.jobs.map { |job| job["args"].first.deep_symbolize_keys }
      expect(notices.size).to eq(2)
      parent_notice = notices.find { |notice| notice[:user_id] == post.user_id }
      Jobs::SendSystemMessage.new.execute(parent_notice)
      expect(Post.last.raw).to include(reason)

      reply_notice = notices.find { |notice| notice[:user_id] == reply.user_id }
      Jobs::SendSystemMessage.new.execute(reply_notice)
      expect(Post.last.raw).to include(
        "More specifically, the post you replied to violated the following community guideline: **#{rule["ground"]}**. #{rule["explanation"]}",
      )
      expect(Post.last.raw).not_to include(reason)
    end

    it "preserves the custom flag reason and the selected rule snapshot" do
      flag = Fabricate(:flag, name: "Unmarked spoilers", notify_type: true)
      reviewable = PostActionCreator.create(flagger, post, flag.name_key.to_sym).reviewable
      Jobs::SendSystemMessage.clear

      reviewable.perform(moderator, :delete_and_agree, dsa_classification: classification)
      SiteSetting.dsa_community_rules = [
        { ground: "Changed rule", explanation: "Changed." },
      ].to_json
      message_args = Jobs::SendSystemMessage.jobs.sole["args"].first.deep_symbolize_keys
      Jobs::SendSystemMessage.new.execute(message_args)

      expect(Post.last.raw).to include("#{flag.name}\n\n#{reason}")
    end
  end
end
