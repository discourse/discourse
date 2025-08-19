# frozen_string_literal: true

describe PostMover do
  fab!(:admin)
  fab!(:user)
  fab!(:topic_1) { Fabricate(:topic, user: user) }
  fab!(:topic_2) { Fabricate(:topic, user: user) }
  fab!(:topic_3) { Fabricate(:topic, user: user) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, user: user) }
  fab!(:post_2) { Fabricate(:post, topic: topic_1, user: user) }
  fab!(:reaction_1) { Fabricate(:reaction, post: post_1, reaction_value: "clap") }
  fab!(:reaction_2) { Fabricate(:reaction, post: post_1, reaction_value: "confetti") }
  fab!(:reaction_3) { Fabricate(:reaction, post: post_2, reaction_value: "heart") }
  fab!(:reaction_4) { Fabricate(:reaction, post: post_2, reaction_value: "wave") }
  fab!(:user_reaction_1) { Fabricate(:reaction_user, reaction: reaction_1, post: post_1) }
  fab!(:user_reaction_2) { Fabricate(:reaction_user, reaction: reaction_2, post: post_1) }
  fab!(:user_reaction_3) { Fabricate(:reaction_user, reaction: reaction_3, post: post_2) }
  fab!(:user_reaction_4) { Fabricate(:reaction_user, reaction: reaction_4, post: post_2) }

  before { SiteSetting.discourse_reactions_enabled = true }

  it "should create new post when topic's first post has no reactions" do
    old_topic = Fabricate(:topic)
    new_topic = Fabricate(:topic)
    post = Fabricate(:post, topic: old_topic)

    post_mover = PostMover.new(old_topic, Discourse.system_user, [post.id])
    expect { post_mover.to_topic(new_topic) }.to change { new_topic.posts.count }.by(1)
  end

  it "should create new post when first post has likes but no emoji reaction user" do
    old_topic = Fabricate(:topic)
    new_topic = Fabricate(:topic)
    post = Fabricate(:post, topic: old_topic)
    Fabricate(:reaction, post: post, reaction_value: "heart")

    PostActionCreator.create(user, post, :like)

    expect(post.reload.like_count).to eq(1)

    post_mover = PostMover.new(old_topic, Discourse.system_user, [post.id])
    expect { post_mover.to_topic(new_topic) }.to change { new_topic.posts.count }.by(1)

    new_post = new_topic.first_post
    expect(new_post.like_count).to eq(1)
    expect(new_post.reactions.count).to eq(1)
    expect(new_post.reactions_user.count).to eq(0)
  end

  xit "should add old post's reactions to new post when a topic's first post is moved" do
    expect(post_1.reactions).to contain_exactly(reaction_1, reaction_2)
    expect(topic_2.posts.count).to eq(0)

    post_mover = PostMover.new(topic_1, Discourse.system_user, [post_1.id])
    expect { post_mover.to_topic(topic_2) }.to change { topic_2.posts.count }.by(1)

    expect(topic_2.posts.count).to eq(1)

    new_post = topic_2.first_post
    reaction_emojis = new_post.reactions.pluck(:reaction_value)

    expect(reaction_emojis.count).to eq(2)
    expect(reaction_emojis).to match_array([reaction_1.reaction_value, reaction_2.reaction_value])

    reaction_user_ids = new_post.reactions_user.pluck(:user_id)
    expect(reaction_user_ids.count).to eq(2)
    expect(reaction_user_ids).to match_array([user_reaction_1.user_id, user_reaction_2.user_id])
  end

  it "should retain existing reactions after moving a post" do
    expect(post_2.reactions).to contain_exactly(reaction_3, reaction_4)
    expect(topic_3.posts.count).to eq(0)

    post_mover = PostMover.new(topic_1, Discourse.system_user, [post_2.id])
    expect { post_mover.to_topic(topic_3) }.to change { topic_3.posts.count }.by(1)

    new_post = topic_3.first_post

    # reaction id does not change as post is updated (unlike first post in topic)
    expect(new_post.reactions.count).to eq(2)
    expect(new_post.reactions).to match_array([reaction_3, reaction_4])

    # reaction_user id does not change as post is updated (unlike first post in topic)
    expect(new_post.reactions_user.count).to eq(2)
    expect(new_post.reactions_user).to match_array([user_reaction_3, user_reaction_4])
  end
end
