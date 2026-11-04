# frozen_string_literal: true

RSpec.describe UserHistorySerializer do
  fab!(:admin)
  fab!(:user)

  it "includes the scheduled expiry" do
    freeze_time
    history =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:suspend_user],
        target_user: user,
        expires_at: 2.days.from_now,
      )

    json = described_class.new(history, scope: admin.guardian, root: false).as_json

    expect(json[:expires_at]).to eq_time(history.expires_at)
  end

  it "leaves expiry unknown for logs without a snapshot" do
    user.update!(suspended_till: 2.days.from_now)
    history =
      Fabricate(:user_history, action: UserHistory.actions[:suspend_user], target_user: user)

    json = described_class.new(history, scope: admin.guardian, root: false).as_json

    expect(json).to have_key(:expires_at)
    expect(json[:expires_at]).to be_nil
  end

  it "redacts expiry when the log content is not visible" do
    post = Fabricate(:private_message_post)
    history =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:silence_user],
        target_user: user,
        post: post,
        expires_at: 2.days.from_now,
      )

    json = described_class.new(history, scope: Fabricate(:moderator).guardian, root: false).as_json

    expect(json[:expires_at]).to be_nil
  end

  describe "full names when names are disabled" do
    fab!(:moderator)
    fab!(:author) { Fabricate(:user, name: "Author Fullname") }
    fab!(:author_topic) { Fabricate(:topic, user: author) }
    fab!(:author_post) do
      Fabricate(
        :post,
        topic: author_topic,
        user: author,
        raw: "Quoting\nuser: someone (kept text)\nraw: more text",
      )
    end

    let(:logger) { StaffActionLogger.new(admin) }

    before { SiteSetting.enable_names = false }

    def details_for(history, viewer)
      described_class.new(history, scope: viewer.guardian, root: false).as_json[:details]
    end

    it "hides the author's name in post and topic logs from moderators" do
      histories = [
        logger.log_post_deletion(author_post),
        logger.log_post_recover(author_post),
        logger.log_topic_delete_recover(author_topic, "delete_topic"),
        logger.log_topic_delete_recover(author_topic, "recover_topic"),
        logger.log_post_rejected(
          Fabricate(:reviewable_queued_post, target_created_by: author),
          Time.zone.now,
        ),
      ]

      details = histories.map { |history| details_for(history, moderator) }

      expect(details).to all(include("user: #{author.username}\n"))
      expect(details.join).not_to include(author.name)
    end

    it "leaves quoted text in post bodies untouched, including when the author is gone" do
      orphan_post = Fabricate(:post, topic: author_topic, raw: author_post.raw)
      orphan_post.update_columns(user_id: nil)
      histories = [
        logger.log_post_deletion(author_post),
        logger.log_post_recover(orphan_post.reload),
      ]

      expect(histories.map { |history| details_for(history, moderator) }).to all(
        include("user: someone (kept text)\nraw: more text"),
      )
    end

    it "hides deleted users' names from moderators, including multiline, label-bearing and legacy entries" do
      deleted_user = Fabricate(:user, name: "Multiline\ncreated_at: Fullname")
      current_entry = logger.log_user_deletion(deleted_user)
      legacy_entry =
        Fabricate(
          :user_history,
          action: UserHistory.actions[:delete_user],
          details:
            "id: 1, username: legacy, name: Legacy, created_at: Fullname, created_at: 2013-05-01, trust_level: 1",
        )

      expect(details_for(current_entry, moderator)).to include(
        "username: #{deleted_user.username}\ncreated_at: ",
      )
      expect(details_for(current_entry, moderator)).not_to include(
        *deleted_user.name.lines.map(&:chomp),
      )
      expect(details_for(legacy_entry, moderator)).to eq(
        "id: 1, username: legacy, created_at: 2013-05-01, trust_level: 1",
      )
    end

    it "shows full names to admins, and to moderators once names are enabled" do
      history = logger.log_post_deletion(author_post)

      expect(details_for(history, admin)).to include("user: #{author.username} (#{author.name})")

      SiteSetting.enable_names = true

      expect(details_for(history, moderator)).to include(
        "user: #{author.username} (#{author.name})",
      )
    end
  end
end
