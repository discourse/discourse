# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schema do
  fab!(:user)
  fab!(:group)
  fab!(:post)

  let(:guardian) { Discourse.system_user.guardian }

  let(:topic_undeclared) do
    %w[
      archetype
      bookmarked
      bumped
      can_vote
      excerpt
      featured_link
      has_accepted_answer
      has_summary
      highest_post_number
      image_url
      last_post_user_id
      last_poster_username
      like_count
      liked
      op_like_count
      pinned
      pinned_globally
      posters
      reply_count
      tags_descriptions
      unpinned
      unseen
      views
      visible
    ]
  end

  def serialized_keys(serializer_class, object)
    MultiJson.load(serializer_class.new(object, scope: guardian, root: false).to_json).keys
  end

  def expect_ledger(declared, emitted, unemitted: [], undeclared: [])
    aggregate_failures do
      expect(declared.keys - emitted - unemitted).to be_empty
      expect(emitted - declared.keys - undeclared).to be_empty
    end
  end

  it "matches DiscourseWorkflows::UserSerializer" do
    expect_ledger(
      described_class::USER_PROPERTIES,
      serialized_keys(DiscourseWorkflows::UserSerializer, user),
    )
  end

  it "matches BasicUserSerializer" do
    expect_ledger(
      described_class::BASIC_USER_PROPERTIES,
      serialized_keys(BasicUserSerializer, user),
    )
  end

  it "matches DiscourseWorkflows::PostSerializer" do
    expect_ledger(
      described_class::POST_PROPERTIES,
      serialized_keys(DiscourseWorkflows::PostSerializer, post),
      unemitted: %w[
        cooked
        cooked_truncated
        cooked_original_length
        raw_truncated
        raw_original_length
      ],
    )
  end

  it "matches DiscourseWorkflows::TopicSerializer" do
    expect_ledger(
      described_class::TOPIC_PROPERTIES,
      serialized_keys(DiscourseWorkflows::TopicSerializer, post.topic),
      undeclared: topic_undeclared,
    )
  end

  it "matches DiscourseWorkflows::TopicListItemSerializer" do
    expect_ledger(
      described_class::TOPIC_PROPERTIES,
      serialized_keys(DiscourseWorkflows::TopicListItemSerializer, post.topic),
      unemitted: %w[first_post_id],
      undeclared: topic_undeclared,
    )
  end

  it "matches WebHookGroupSerializer" do
    expect_ledger(
      described_class::GROUP_PROPERTIES,
      serialized_keys(WebHookGroupSerializer, group),
      undeclared: %w[
        bio_raw
        can_admin_group
        can_edit_group
        display_name
        has_messages
        incoming_email
      ],
    )
  end

  it "matches the group payload the membership triggers build" do
    trigger = DiscourseWorkflows::Nodes::UserAddedToGroup::V1.new(user, group)

    expect_ledger(described_class::BASIC_GROUP_PROPERTIES, trigger.output[:group].keys.map(&:to_s))
  end
end
