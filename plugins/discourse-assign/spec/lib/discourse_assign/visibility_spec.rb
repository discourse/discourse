# frozen_string_literal: true

RSpec.describe DiscourseAssign::Visibility do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:participant, :user)
  fab!(:outsider, :user)
  fab!(:category_group, :group)
  fab!(:category_member) { Fabricate(:user, groups: [category_group]) }
  fab!(:private_category) { Fabricate(:private_category, group: category_group) }
  fab!(:restricted_topic) { Fabricate(:topic, category: private_category, user: author) }
  fab!(:private_message) { Fabricate(:private_message_topic, user: author, recipient: participant) }
  fab!(:whisper_group, :group)
  fab!(:whisperer) { Fabricate(:user, groups: [whisper_group]) }
  fab!(:hidden_viewer_group, :group)
  fab!(:hidden_viewer) { Fabricate(:user, groups: [hidden_viewer_group]) }
  fab!(:public_topic) { Fabricate(:topic, user: author) }

  let(:users) do
    [admin, moderator, author, participant, outsider, category_member, whisperer, hidden_viewer]
  end

  before do
    SiteSetting.whispers_allowed_groups = whisper_group.id.to_s
    SiteSetting.hidden_post_visible_groups = hidden_viewer_group.id.to_s
  end

  def expect_visibility_to_match_guardian(target)
    visible_ids = described_class.visible_users(target).pluck(:id)

    expect(users.map { |user| user.guardian.can_see?(target) }).to eq(
      users.map { |user| visible_ids.include?(user.id) },
    )
  end

  it "matches guardian visibility for a public topic" do
    expect_visibility_to_match_guardian(public_topic)
  end

  it "matches guardian visibility for a restricted category topic" do
    expect_visibility_to_match_guardian(restricted_topic)
  end

  it "matches guardian visibility for a private message" do
    expect_visibility_to_match_guardian(private_message)
  end

  it "matches guardian visibility for a regular post" do
    expect_visibility_to_match_guardian(Fabricate(:post, topic: public_topic, user: author))
  end

  it "matches guardian visibility for a whisper" do
    expect_visibility_to_match_guardian(
      Fabricate(:post, topic: public_topic, user: author, post_type: Post.types[:whisper]),
    )
  end

  it "matches guardian visibility for a hidden post" do
    expect_visibility_to_match_guardian(
      Fabricate(:post, topic: public_topic, user: author, hidden: true),
    )
  end

  it "matches guardian visibility for a post in a restricted category" do
    expect_visibility_to_match_guardian(Fabricate(:post, topic: restricted_topic, user: author))
  end

  it "matches guardian visibility for a post in a private message" do
    expect_visibility_to_match_guardian(Fabricate(:post, topic: private_message, user: author))
  end

  context "with category group moderation" do
    fab!(:moderation_group, :group)
    fab!(:moderated_member) { Fabricate(:user, groups: [category_group, moderation_group]) }
    fab!(:moderation_only_member) { Fabricate(:user, groups: [moderation_group]) }
    fab!(:hidden_post) { Fabricate(:post, topic: restricted_topic, user: author, hidden: true) }

    before do
      SiteSetting.enable_category_group_moderation = true
      CategoryModerationGroup.create!(category: private_category, group: moderation_group)
    end

    it "includes moderators who can see the category" do
      visible_ids = described_class.visible_users(hidden_post).pluck(:id)

      expect(visible_ids).to include(moderated_member.id)
      expect(moderated_member.guardian.can_see_post?(hidden_post)).to eq(true)
    end

    it "excludes moderators who cannot see the category" do
      expect(described_class.visible_users(restricted_topic).pluck(:id)).not_to include(
        moderation_only_member.id,
      )
      expect(moderation_only_member.guardian.can_see_topic?(restricted_topic)).to eq(false)
    end
  end

  describe ".visible_to_all_users?" do
    it "is true for a public topic and its regular posts" do
      post = Fabricate(:post, topic: public_topic, user: author)

      expect(described_class.visible_to_all_users?(public_topic)).to eq(true)
      expect(described_class.visible_to_all_users?(post)).to eq(true)
    end

    it "is false for restricted targets" do
      whisper = Fabricate(:post, topic: public_topic, post_type: Post.types[:whisper])
      hidden_post = Fabricate(:post, topic: public_topic, hidden: true)
      trashed_post = Fabricate(:post, topic: public_topic, deleted_at: 1.minute.ago)

      expect(described_class.visible_to_all_users?(restricted_topic)).to eq(false)
      expect(described_class.visible_to_all_users?(private_message)).to eq(false)
      expect(described_class.visible_to_all_users?(whisper)).to eq(false)
      expect(described_class.visible_to_all_users?(hidden_post)).to eq(false)
      expect(described_class.visible_to_all_users?(trashed_post)).to eq(false)
    end
  end
end
