# frozen_string_literal: true

RSpec.describe WebHookPostSerializer do
  fab!(:admin)
  fab!(:post)

  def serialized_for_user(u)
    WebHookPostSerializer.new(post, scope: Guardian.new(u), root: false).as_json
  end

  it "should only include the required keys" do
    expect(serialized_for_user(admin).keys).to contain_exactly(
      :id,
      :name,
      :username,
      :avatar_template,
      :created_at,
      :cooked,
      :post_number,
      :post_type,
      :posts_count,
      :updated_at,
      :reply_count,
      :reply_to_post_number,
      :quote_count,
      :incoming_link_count,
      :reads,
      :score,
      :topic_id,
      :topic_slug,
      :topic_title,
      :category_id,
      :display_username,
      :primary_group_name,
      :flair_name,
      :flair_group_id,
      :version,
      :user_title,
      :bookmarked,
      :raw,
      :moderator,
      :admin,
      :staff,
      :user_id,
      :hidden,
      :trust_level,
      :deleted_at,
      :user_deleted,
      :edit_reason,
      :wiki,
      :reviewable_id,
      :reviewable_score_count,
      :reviewable_score_pending_count,
      :post_url,
      :topic_posts_count,
      :topic_filtered_posts_count,
      :topic_archetype,
      :category_slug,
    )
  end

  it "includes category_id" do
    expect(serialized_for_user(admin)[:category_id]).to eq(post.topic.category_id)
  end

  it "should only include deleted topic title for staffs" do
    topic = post.topic
    PostDestroyer.new(Discourse.system_user, post).destroy
    post.reload

    [nil, post.user, Fabricate(:user)].each do |user|
      expect(serialized_for_user(user)[:topic_title]).to eq(nil)
    end

    [Fabricate(:moderator), admin].each do |user|
      expect(serialized_for_user(user)[:topic_title]).to eq(topic.title)
    end
  end
end
