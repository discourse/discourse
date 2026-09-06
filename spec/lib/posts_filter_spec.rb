# frozen_string_literal: true

RSpec.describe PostsFilter do
  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_topic_title_length = 3
  end

  fab!(:user)
  fab!(:user2, :user)
  fab!(:admin)
  fab!(:feature_tag) { Fabricate(:tag, name: "feature") }
  fab!(:bug_tag) { Fabricate(:tag, name: "bug") }
  fab!(:announcement_category) { Fabricate(:category, name: "Announcements") }
  fab!(:feedback_category) { Fabricate(:category, name: "Feedback") }

  fab!(:feature_topic) do
    Fabricate(
      :topic,
      user: user,
      tags: [feature_tag],
      category: announcement_category,
      title: "New Feature Discussion",
    )
  end

  fab!(:bug_topic) do
    Fabricate(
      :topic,
      tags: [bug_tag],
      user: user,
      category: announcement_category,
      title: "Bug Report Discussion",
    )
  end

  fab!(:feature_bug_topic) do
    Fabricate(
      :topic,
      tags: [feature_tag, bug_tag],
      user: user,
      category: feedback_category,
      title: "Feature with Bug",
    )
  end

  fab!(:no_tag_topic) do
    Fabricate(:topic, user: user, category: feedback_category, title: "General Discussion")
  end

  fab!(:feature_post) { Fabricate(:post, topic: feature_topic, user: user, post_number: 1) }
  fab!(:bug_post) { Fabricate(:post, topic: bug_topic, user: user, post_number: 1) }
  fab!(:feature_bug_post) { Fabricate(:post, topic: feature_bug_topic, user: user, post_number: 1) }
  fab!(:no_tag_post) { Fabricate(:post, topic: no_tag_topic, user: user, post_number: 1) }

  def filtered_post_ids(query, guardian: nil, limit: nil, offset: nil, scope: Post.all)
    described_class
      .new(query, guardian: guardian, limit: limit, offset: offset, scope: scope)
      .search
      .pluck(:id)
  end

  it "returns enum filter values as server-supplied suggestions" do
    options = described_class.option_info(user.guardian)

    expect(options).to include(
      { name: "order:", description: I18n.t("posts_filter.description.order"), priority: 1 },
      { name: "order:latest", description: I18n.t("posts_filter.description.order_latest") },
      { name: "status:open", description: I18n.t("posts_filter.description.status_open") },
      { name: "status:listed", description: I18n.t("posts_filter.description.status_listed") },
      { name: "status:unlisted", description: I18n.t("posts_filter.description.status_unlisted") },
      { name: "status:deleted", description: I18n.t("posts_filter.description.status_deleted") },
      { name: "status:public", description: I18n.t("posts_filter.description.status_public") },
      {
        name: "post_type:regular",
        description: I18n.t("posts_filter.description.post_type_regular"),
      },
      { name: "post_type:all", description: I18n.t("posts_filter.description.post_type_all") },
      { name: "post_type:first", description: I18n.t("posts_filter.description.post_type_first") },
      {
        name: "post_type:moderator_action",
        description: I18n.t("posts_filter.description.post_type_moderator_action"),
      },
      {
        name: "post_type:small_action",
        description: I18n.t("posts_filter.description.post_type_small_action"),
      },
      {
        name: "post_type:whisper",
        description: I18n.t("posts_filter.description.post_type_whisper"),
      },
    )
    expect(options.find { |option| option[:name] == "topic:" }).to include(
      prefixes: [{ name: "-", description: I18n.t("posts_filter.description.exclude_topic") }],
    )
    expect(options.find { |option| option[:name] == "order:" }).not_to include(
      :type,
      :extra_entries,
    )
  end

  it "filters posts by tags and categories" do
    expect(filtered_post_ids("tag:feature")).to contain_exactly(
      feature_post.id,
      feature_bug_post.id,
    )
    expect(filtered_post_ids("tags:bug")).to contain_exactly(bug_post.id, feature_bug_post.id)
    expect(filtered_post_ids("category:Announcements")).to contain_exactly(
      feature_post.id,
      bug_post.id,
    )
    expect(filtered_post_ids("categories:Feedback tag:feature")).to contain_exactly(
      feature_bug_post.id,
    )
  end

  it "supports exact and nested category matching" do
    child_category =
      Fabricate(
        :category,
        name: "Announcements Child",
        parent_category_id: announcement_category.id,
      )
    child_topic =
      Fabricate(:topic, user: user, category: child_category, title: "Child Category Discussion")
    child_post = Fabricate(:post, topic: child_topic, user: user, post_number: 1)

    expect(filtered_post_ids("category:Announcements")).to contain_exactly(
      feature_post.id,
      bug_post.id,
      child_post.id,
    )
    expect(filtered_post_ids("category:=Announcements")).to contain_exactly(
      feature_post.id,
      bug_post.id,
    )
    expect(
      filtered_post_ids("category:#{announcement_category.slug}/#{child_category.slug}"),
    ).to contain_exactly(child_post.id)
    expect(filtered_post_ids('category:"Announcements Child"')).to contain_exactly(child_post.id)
  end

  it "supports category and tag exclusions" do
    expect(filtered_post_ids("-category:Announcements")).to contain_exactly(
      feature_bug_post.id,
      no_tag_post.id,
    )
    expect(filtered_post_ids("exclude_categories:Feedback")).to contain_exactly(
      feature_post.id,
      bug_post.id,
    )
    expect(filtered_post_ids("-tag:feature")).to contain_exactly(bug_post.id, no_tag_post.id)
    expect(filtered_post_ids("exclude_tags:bug")).to contain_exactly(
      feature_post.id,
      no_tag_post.id,
    )
  end

  it "filters posts by users and groups" do
    group1 = Fabricate(:group, name: "group1")
    group2 = Fabricate(:group, name: "group2")
    group1.add(user)
    group2.add(user2)
    no_tag_post.update!(user_id: user2.id)

    expect(filtered_post_ids("username:#{user.username}")).to contain_exactly(
      feature_post.id,
      bug_post.id,
      feature_bug_post.id,
    )
    expect(filtered_post_ids("groups:group1,group2")).to contain_exactly(
      feature_post.id,
      bug_post.id,
      feature_bug_post.id,
      no_tag_post.id,
    )
  end

  it "supports unicode usernames" do
    SiteSetting.unicode_usernames = true
    unicode_user = Fabricate(:user, username: "aאb")
    unicode_post = Fabricate(:post, user: unicode_user, topic: feature_topic, post_number: 2)

    expect(filtered_post_ids("username:aאb")).to contain_exactly(unicode_post.id)
  end

  it "filters posts by topic, post type, status, dates, and limits" do
    feature_post.update_columns(created_at: 3.days.ago)
    bug_post.update_columns(created_at: 2.days.ago)
    feature_bug_post.update_columns(created_at: 1.day.ago)
    feature_topic.update_columns(created_at: 4.days.ago)
    bug_topic.update_columns(closed: true, created_at: 2.days.ago)

    reply_post = Fabricate(:post, topic: feature_topic, user: user, post_number: 2)

    expect(filtered_post_ids("topic:#{feature_topic.id}")).to contain_exactly(
      feature_post.id,
      reply_post.id,
    )
    expect(filtered_post_ids("-topic:#{feature_topic.id}")).to contain_exactly(
      bug_post.id,
      feature_bug_post.id,
      no_tag_post.id,
    )
    expect(filtered_post_ids("-topic:#{feature_topic.id},#{bug_topic.id}")).to contain_exactly(
      feature_bug_post.id,
      no_tag_post.id,
    )
    expect(filtered_post_ids("post_type:first")).to contain_exactly(
      feature_post.id,
      bug_post.id,
      feature_bug_post.id,
      no_tag_post.id,
    )
    expect(filtered_post_ids("post_type:reply")).to contain_exactly(reply_post.id)
    expect(filtered_post_ids("status:closed")).to contain_exactly(bug_post.id)
    expect(filtered_post_ids("after:#{2.days.ago.to_date}")).to include(feature_bug_post.id)
    expect(filtered_post_ids("topic_before:#{3.days.ago.to_date}")).to contain_exactly(
      feature_post.id,
      reply_post.id,
    )
    expect(filtered_post_ids("category:Feedback max_results:1", limit: 5).length).to eq(1)
  end

  it "defaults to regular posts and allows explicit post types" do
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s

    topic = Fabricate(:topic, user: user, category: announcement_category)
    regular_post = Fabricate(:post, topic: topic, user: user, post_number: 1)
    reply_post = Fabricate(:post, topic: topic, user: user, post_number: 2)
    moderator_action_post =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        post_number: 3,
        post_type: Post.types[:moderator_action],
      )
    small_action_post =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        post_number: 4,
        post_type: Post.types[:small_action],
      )
    whisper_post =
      Fabricate(:post, topic: topic, user: admin, post_number: 5, post_type: Post.types[:whisper])
    post_ids = [
      regular_post.id,
      reply_post.id,
      moderator_action_post.id,
      small_action_post.id,
      whisper_post.id,
    ]
    scope = Post.where(id: post_ids)

    expect(filtered_post_ids("", guardian: admin.guardian, scope: scope)).to contain_exactly(
      regular_post.id,
      reply_post.id,
    )
    expect(
      filtered_post_ids("post_type:all", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(*post_ids)
    expect(
      filtered_post_ids("post_type:moderator_action", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(moderator_action_post.id)
    expect(
      filtered_post_ids("post_type:small_action", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(small_action_post.id)
    expect(
      filtered_post_ids("post_type:whisper", guardian: user.guardian, scope: scope),
    ).to be_empty
    expect(
      filtered_post_ids("post_type:whisper", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(whisper_post.id)
    expect(
      filtered_post_ids("post_type:first", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(regular_post.id)
    expect(
      filtered_post_ids("post_type:reply", guardian: admin.guardian, scope: scope),
    ).to contain_exactly(reply_post.id)
    expect(
      filtered_post_ids(
        "post_type:small_action OR username:#{user.username}",
        guardian: admin.guardian,
        scope: scope,
      ),
    ).to contain_exactly(small_action_post.id, regular_post.id, reply_post.id)
  end

  it "keeps post_type all within guardian visibility" do
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s

    topic = Fabricate(:topic, user: user, category: announcement_category)
    regular_post = Fabricate(:post, topic: topic, user: user)
    small_action_post =
      Fabricate(:post, topic: topic, user: admin, post_type: Post.types[:small_action])
    hidden_post = Fabricate(:post, topic: topic, user: user2)
    hidden_post.update_columns(hidden: true)
    whisper_post = Fabricate(:post, topic: topic, user: admin, post_type: Post.types[:whisper])
    secure_category = Fabricate(:private_category, group: Fabricate(:group))
    secure_topic = Fabricate(:topic, user: user, category: secure_category)
    secure_post = Fabricate(:post, topic: secure_topic, user: user)
    pm_topic = Fabricate(:private_message_topic, user: user, recipient: user2)
    pm_post = Fabricate(:post, topic: pm_topic, user: user)
    scope =
      Post.where(
        id: [
          regular_post.id,
          small_action_post.id,
          hidden_post.id,
          whisper_post.id,
          secure_post.id,
          pm_post.id,
        ],
      )

    expect(
      filtered_post_ids("post_type:all", guardian: user.guardian, scope: scope),
    ).to contain_exactly(regular_post.id, small_action_post.id)
  end

  it "filters posts by listed, unlisted, deleted, and public topic statuses" do
    listed_topic = Fabricate(:topic, user: user, category: announcement_category)
    listed_post = Fabricate(:post, topic: listed_topic, user: user)
    unlisted_topic = Fabricate(:topic, user: user, category: announcement_category, visible: false)
    unlisted_post = Fabricate(:post, topic: unlisted_topic, user: user)
    deleted_topic = Fabricate(:topic, user: user, category: announcement_category)
    deleted_post = Fabricate(:post, topic: deleted_topic, user: user)
    PostDestroyer.new(admin, deleted_post, context: "spec").destroy

    status_scope = Post.where(id: [listed_post.id, unlisted_post.id, deleted_post.id])

    expect(
      filtered_post_ids("status:listed", guardian: admin.guardian, scope: status_scope),
    ).to contain_exactly(listed_post.id)
    expect(
      filtered_post_ids("status:unlisted", guardian: admin.guardian, scope: status_scope),
    ).to contain_exactly(unlisted_post.id)
    expect(
      filtered_post_ids("status:deleted", guardian: admin.guardian, scope: status_scope),
    ).to contain_exactly(deleted_post.id)
    expect(
      filtered_post_ids("status:deleted", guardian: user.guardian, scope: status_scope),
    ).to be_empty

    secure_group = Fabricate(:group)
    secure_group.add(user)
    secure_category = Fabricate(:private_category, group: secure_group)
    secure_topic = Fabricate(:topic, user: user, category: secure_category)
    secure_post = Fabricate(:post, topic: secure_topic, user: user)
    uncategorized_topic = Fabricate(:topic, user: user, category: nil)
    uncategorized_post = Fabricate(:post, topic: uncategorized_topic, user: user)
    public_scope = Post.where(id: [listed_post.id, secure_post.id, uncategorized_post.id])

    expect(filtered_post_ids("", guardian: user.guardian, scope: public_scope)).to contain_exactly(
      listed_post.id,
      secure_post.id,
      uncategorized_post.id,
    )
    expect(
      filtered_post_ids("status:public", guardian: user.guardian, scope: public_scope),
    ).to contain_exactly(listed_post.id, uncategorized_post.id)

    deleted_reply = Fabricate(:post, topic: listed_topic, user: user)
    PostDestroyer.new(admin, deleted_reply, context: "spec").destroy

    or_scope = Post.where(id: [listed_post.id, secure_post.id, deleted_post.id, deleted_reply.id])
    expect(
      filtered_post_ids(
        "status:deleted OR status:public",
        guardian: admin.guardian,
        scope: or_scope,
      ),
    ).to contain_exactly(deleted_post.id, listed_post.id)
  end

  it "orders posts" do
    feature_post.update_columns(created_at: 3.days.ago, like_count: 1)
    bug_post.update_columns(created_at: 2.days.ago, like_count: 5)
    feature_bug_post.update_columns(created_at: 1.day.ago, like_count: 2)

    expect(filtered_post_ids("category:Announcements order:oldest")).to eq(
      [feature_post.id, bug_post.id],
    )
    expect(filtered_post_ids("order:likes").first).to eq(bug_post.id)
  end

  it "supports OR groups" do
    expect(filtered_post_ids("category:Announcements OR tag:feature")).to contain_exactly(
      feature_post.id,
      bug_post.id,
      feature_bug_post.id,
    )
  end

  it "filters posts and topics by full text keywords" do
    SearchIndexer.enable
    post_with_apples = Fabricate(:post, raw: "This post contains apples", topic: feature_topic)
    post_with_bananas = Fabricate(:post, raw: "This post mentions bananas", topic: bug_topic)
    post_with_both =
      Fabricate(:post, raw: "This post has apples and bananas", topic: feature_bug_topic)
    Fabricate(:post, raw: "No fruits here", topic: no_tag_topic)
    reply_on_bananas_topic = Fabricate(:post, raw: "Just a reply", topic: post_with_bananas.topic)

    expect(filtered_post_ids("keywords:apples")).to contain_exactly(
      post_with_apples.id,
      post_with_both.id,
    )
    expect(filtered_post_ids("keywords:apples,bananas")).to contain_exactly(
      post_with_apples.id,
      post_with_bananas.id,
      post_with_both.id,
    )
    expect(filtered_post_ids("topic_keywords:banana")).to contain_exactly(
      bug_post.id,
      post_with_bananas.id,
      reply_on_bananas_topic.id,
      feature_bug_post.id,
      post_with_both.id,
    )
  end

  it "tracks invalid filter fragments" do
    filter = described_class.new("invalidfilter tag:feature order:missing")

    expect(filter.invalid_filters).to contain_exactly("invalidfilter", "order:missing")
  end

  it "omits secure categories without a guardian and always omits PMs" do
    secure_group = Fabricate(:group)
    secure_category = Fabricate(:category, name: "Secure")
    secure_category.set_permissions(secure_group => :readonly)
    secure_category.save!
    secure_topic =
      Fabricate(:topic, category: secure_category, user: user, title: "Secret Topic Discussion")
    secure_post = Fabricate(:post, topic: secure_topic, user: user)
    pm_topic = Fabricate(:private_message_topic, user: user)
    pm_post = Fabricate(:post, topic: pm_topic, user: user)

    expect(filtered_post_ids("")).not_to include(secure_post.id, pm_post.id)

    secure_group.add(user)
    expect(filtered_post_ids("", guardian: Guardian.new(user))).to include(secure_post.id)
    expect(filtered_post_ids("", guardian: Guardian.new(user))).not_to include(pm_post.id)
  end

  it "supports filter_from_query_string and custom filters" do
    described_class.add_filter("min_likes") do |scope, values, _guardian|
      scope.where("posts.like_count >= ?", values.first.to_i)
    end
    bug_post.update!(like_count: 3)

    result = described_class.new(guardian: Guardian.new).filter_from_query_string("min_likes:2")

    expect(result.pluck(:id)).to contain_exactly(bug_post.id)
  ensure
    described_class.remove_filter("min_likes")
  end

  it "applies guardian visibility to hidden posts and unlisted topics" do
    hidden_post = Fabricate(:post, topic: feature_topic, user: user2, post_number: 2, hidden: true)
    unlisted_topic = Fabricate(:topic, user: user, visible: false, title: "Unlisted Discussion")
    unlisted_post = Fabricate(:post, topic: unlisted_topic, user: user, post_number: 1)

    expect(filtered_post_ids("", guardian: Guardian.new(user))).not_to include(
      hidden_post.id,
      unlisted_post.id,
    )

    expect(filtered_post_ids("", guardian: Guardian.new(Fabricate(:admin)))).to include(
      hidden_post.id,
      unlisted_post.id,
    )
  end

  it "only filters by tags visible to the guardian" do
    hidden_tag = Fabricate(:tag, name: "hidden")
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    hidden_tag_topic = Fabricate(:topic, user: user, tags: [hidden_tag], title: "Hidden Tag Topic")
    hidden_tag_post = Fabricate(:post, topic: hidden_tag_topic, user: user, post_number: 1)

    expect(
      filtered_post_ids("tag:#{hidden_tag.name}", guardian: Guardian.new(user)),
    ).not_to include(hidden_tag_post.id)
    expect(
      filtered_post_ids("tag:#{hidden_tag.name}", guardian: Guardian.new(Fabricate(:admin))),
    ).to include(hidden_tag_post.id)
  end

  it "only filters by groups with visible memberships" do
    private_group =
      Fabricate(
        :group,
        name: "private_group",
        visibility_level: Group.visibility_levels[:staff],
        members_visibility_level: Group.visibility_levels[:staff],
      )
    private_group.add(user2)
    private_group_post = Fabricate(:post, topic: feature_topic, user: user2, post_number: 2)

    expect(
      filtered_post_ids("group:#{private_group.name}", guardian: Guardian.new(user)),
    ).not_to include(private_group_post.id)
    expect(
      filtered_post_ids("group:#{private_group.name}", guardian: Guardian.new(Fabricate(:admin))),
    ).to include(private_group_post.id)
  end

  it "does not match topic keywords from hidden posts for users who cannot see them" do
    SearchIndexer.enable
    hidden_post =
      Fabricate(
        :post,
        topic: feature_topic,
        user: user,
        post_number: 2,
        raw: "needleword only in a hidden post",
        hidden: true,
      )
    SearchIndexer.index(hidden_post, force: true)

    expect(filtered_post_ids("topic_keywords:needleword", guardian: Guardian.new(user))).to be_empty
    expect(
      filtered_post_ids("topic_keywords:needleword", guardian: Guardian.new(Fabricate(:admin))),
    ).to include(feature_post.id, hidden_post.id)
  ensure
    SearchIndexer.disable
  end
end
