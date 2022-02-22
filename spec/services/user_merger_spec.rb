# frozen_string_literal: true

require 'rails_helper'

describe UserMerger do
  fab!(:target_user) { Fabricate(:user, username: 'alice', email: 'alice@example.com') }
  fab!(:source_user) { Fabricate(:user, username: 'alice1', email: 'alice@work.com') }
  fab!(:walter) { Fabricate(:walter_white) }
  fab!(:coding_horror) { Fabricate(:coding_horror) }

  fab!(:p1) { Fabricate(:post) }
  fab!(:p2) { Fabricate(:post) }
  fab!(:p3) { Fabricate(:post) }
  fab!(:p4) { Fabricate(:post) }
  fab!(:p5) { Fabricate(:post) }
  fab!(:p6) { Fabricate(:post) }

  def merge_users!(source = nil, target =  nil)
    source ||= source_user
    target ||= target_user
    UserMerger.new(source, target).merge!
  end

  it "changes owner of topics and posts" do
    topic1 = Fabricate(:topic, user: source_user)
    post1 = Fabricate(:post, topic: topic1, user: source_user)
    post2 = Fabricate(:post, topic: topic1, user: walter)
    post3 = Fabricate(:post, topic: topic1, user: target_user)
    post4 = Fabricate(:post, topic: topic1, user: walter)
    post5 = Fabricate(:post, topic: topic1, user: source_user)

    topic2 = Fabricate(:topic, user: walter)
    post6 = Fabricate(:post, topic: topic2, user: walter)
    post7 = Fabricate(:post, topic: topic2, user: source_user)
    post8 = Fabricate(:post, topic: topic2, user: source_user, deleted_at: Time.now)

    merge_users!

    [topic1, post1, post3, post5, post7, post8].each do |x|
      expect(x.reload.user).to eq(target_user)
    end

    [post2, post4, topic2, post6].each do |x|
      expect(x.reload.user).to eq(walter)
    end
  end

  it "changes owner of personal messages" do
    pm_topic = Fabricate(:private_message_topic, topic_allowed_users: [
      Fabricate.build(:topic_allowed_user, user: target_user),
      Fabricate.build(:topic_allowed_user, user: walter),
      Fabricate.build(:topic_allowed_user, user: source_user)
    ])

    post1 = Fabricate(:post, topic: pm_topic, user: source_user)
    post2 = Fabricate(:post, topic: pm_topic, user: walter)
    post3 = Fabricate(:post, topic: pm_topic, user: target_user)
    post4 = Fabricate(:post, topic: pm_topic, user: source_user, deleted_at: Time.now)

    small1 = pm_topic.add_small_action(source_user, "invited_user", "carol")
    small2 = pm_topic.add_small_action(target_user, "invited_user", "david")
    small3 = pm_topic.add_small_action(walter, "invited_user", "eve")

    merge_users!

    expect(post1.reload.user).to eq(target_user)
    expect(post2.reload.user).to eq(walter)
    expect(post3.reload.user).to eq(target_user)
    expect(post4.reload.user).to eq(target_user)

    expect(small1.reload.user).to eq(target_user)
    expect(small2.reload.user).to eq(target_user)
    expect(small3.reload.user).to eq(walter)
  end

  it "changes owner of categories" do
    category = Fabricate(:category, user: source_user)
    merge_users!

    expect(category.reload.user).to eq(target_user)
  end

  it "merges category notification settings" do
    category1 = Fabricate(:category)
    category2 = Fabricate(:category)
    category3 = Fabricate(:category)
    watching = CategoryUser.notification_levels[:watching]

    CategoryUser.batch_set(source_user, :watching, [category1.id, category2.id])
    CategoryUser.batch_set(target_user, :watching, [category2.id, category3.id])

    merge_users!

    category_ids = CategoryUser.where(user_id: target_user.id, notification_level: watching).pluck(:category_id)
    expect(category_ids).to contain_exactly(category1.id, category2.id, category3.id)

    category_ids = CategoryUser.where(user_id: source_user.id, notification_level: watching).pluck(:category_id)
    expect(category_ids).to be_empty
  end

  context "developer flag" do
    it "moves the developer flag when the target user isn't a developer yet" do
      Developer.create!(user_id: source_user.id)
      merge_users!

      expect(Developer.where(user_id: source_user.id).count).to eq(0)
      expect(Developer.where(user_id: target_user.id).count).to eq(1)
    end

    it "deletes the source's developer flag when the target user is already a developer" do
      Developer.create!(user_id: source_user.id)
      Developer.create!(user_id: target_user.id)
      merge_users!

      expect(Developer.where(user_id: source_user.id).count).to eq(0)
      expect(Developer.where(user_id: target_user.id).count).to eq(1)
    end
  end

  context "drafts" do
    def create_draft(user, key, text)
      seq = DraftSequence.next!(user, key)
      Draft.set(user, key, seq, text)
    end

    def current_target_user_draft(key)
      seq = DraftSequence.current(target_user, key)
      Draft.get(target_user, key, seq)
    end

    it "merges drafts" do
      key_topic_17 = "#{Draft::EXISTING_TOPIC}#{17}"
      key_topic_19 = "#{Draft::EXISTING_TOPIC}#{19}"

      create_draft(source_user, Draft::NEW_TOPIC, 'new topic draft by alice1')
      create_draft(source_user, key_topic_17, 'draft by alice1')
      create_draft(source_user, key_topic_19,  'draft by alice1')
      create_draft(target_user, key_topic_19,  'draft by alice')

      merge_users!

      expect(current_target_user_draft(Draft::NEW_TOPIC)).to eq('new topic draft by alice1')
      expect(current_target_user_draft(key_topic_17)).to eq('draft by alice1')
      expect(current_target_user_draft(key_topic_19)).to eq('draft by alice')

      expect(DraftSequence.where(user_id: source_user.id).count).to eq(0)
      expect(Draft.where(user_id: source_user.id).count).to eq(0)
    end
  end

  it "updates email logs" do
    Fabricate(:email_log, user: source_user)
    merge_users!

    expect(EmailLog.where(user_id: source_user.id).count).to eq(0)
    expect(EmailLog.where(user_id: target_user.id).count).to eq(1)
  end

  context "likes" do
    def given_daily_like_count_for(user, date)
      GivenDailyLike.find_for(user.id, date).pluck(:likes_given)[0] || 0
    end

    it "merges likes" do
      now = Time.zone.now

      freeze_time(now - 1.day)
      PostActionCreator.like(source_user, p1)
      PostActionCreator.like(source_user, p2)
      PostActionCreator.like(target_user, p2)
      PostActionCreator.like(target_user, p3)

      freeze_time(now)
      PostActionCreator.like(source_user, p4)
      PostActionCreator.like(source_user, p5)
      PostActionCreator.like(target_user, p5)
      PostActionCreator.like(source_user, p6)
      PostActionDestroyer.destroy(source_user, p6, :like)

      merge_users!

      [p1, p2, p3, p4, p5].each { |p| expect(p.reload.like_count).to eq(1) }
      expect(PostAction.with_deleted.where(user_id: source_user.id).count).to eq(0)
      expect(PostAction.with_deleted.where(user_id: target_user.id).count).to eq(6)

      expect(given_daily_like_count_for(source_user, Date.yesterday)).to eq(0)
      expect(given_daily_like_count_for(target_user, Date.yesterday)).to eq(3)
      expect(given_daily_like_count_for(source_user, Date.today)).to eq(0)
      expect(given_daily_like_count_for(target_user, Date.today)).to eq(2)
    end
  end

  it "updates group history" do
    group = Fabricate(:group)
    group.add_owner(source_user)
    logger = GroupActionLogger.new(source_user, group)
    logger.log_add_user_to_group(walter)
    logger.log_add_user_to_group(target_user)

    group = Fabricate(:group)
    group.add_owner(target_user)
    logger = GroupActionLogger.new(target_user, group)
    logger.log_add_user_to_group(walter)
    logger.log_add_user_to_group(source_user)

    merge_users!

    expect(GroupHistory.where(acting_user_id: source_user.id).count).to eq(0)
    expect(GroupHistory.where(acting_user_id: target_user.id).count).to eq(4)

    expect(GroupHistory.where(target_user_id: source_user.id).count).to eq(0)
    expect(GroupHistory.where(target_user_id: target_user.id).count).to eq(2)
  end

  it "merges group memberships" do
    group1 = Fabricate(:group)
    group1.add_owner(target_user)
    group1.bulk_add([walter.id, source_user.id])

    group2 = Fabricate(:group)
    group2.bulk_add([walter.id, target_user.id])

    group3 = Fabricate(:group)
    group3.add_owner(source_user)
    group3.add(walter)

    merge_users!

    [group1, group2, group3].each do |g|
      owner = [group1, group3].include?(g)
      expect(GroupUser.where(group_id: g.id, user_id: target_user.id, owner: owner).count).to eq(1)
      expect(Group.where(id: g.id).pluck_first(:user_count)).to eq(2)
    end
    expect(GroupUser.where(user_id: source_user.id).count).to eq(0)
  end

  it "updates incoming emails" do
    email = Fabricate(:incoming_email, user: source_user)
    merge_users!

    expect(email.reload.user).to eq(target_user)
  end

  it "updates incoming links" do
    link1 = Fabricate(:incoming_link, user: source_user)
    link2 = Fabricate(:incoming_link, current_user_id: source_user.id)

    merge_users!

    expect(link1.reload.user).to eq(target_user)
    expect(link2.reload.current_user_id).to eq(target_user.id)
  end

  it "updates invites" do
    invite1 = Fabricate(:invite, invited_by: walter)
    Fabricate(:invited_user, invite: invite1, user: source_user)
    invite2 = Fabricate(:invite, invited_by: source_user)
    invite3 = Fabricate(:invite, invited_by: source_user)
    invite3.trash!(source_user)

    merge_users!

    [invite1, invite2, invite3].each { |x| x.reload }

    expect(invite1.invited_users.first.user).to eq(target_user)
    expect(invite2.invited_by).to eq(target_user)
    expect(invite3.invited_by).to eq(target_user)
    expect(invite3.deleted_by).to eq(target_user)
  end

  it "merges muted users" do
    muted1 = Fabricate(:user)
    muted2 = Fabricate(:user)
    muted3 = Fabricate(:user)

    MutedUser.create!(user_id: source_user.id, muted_user_id: muted1.id)
    MutedUser.create!(user_id: source_user.id, muted_user_id: muted2.id)
    MutedUser.create!(user_id: target_user.id, muted_user_id: muted2.id)
    MutedUser.create!(user_id: target_user.id, muted_user_id: muted3.id)
    MutedUser.create!(user_id: walter.id, muted_user_id: source_user.id)
    MutedUser.create!(user_id: coding_horror.id, muted_user_id: source_user.id)
    MutedUser.create!(user_id: coding_horror.id, muted_user_id: target_user.id)

    merge_users!

    [muted1, muted2, muted3].each do |m|
      expect(MutedUser.where(user_id: target_user.id, muted_user_id: m.id).count).to eq(1)
    end
    expect(MutedUser.where(user_id: source_user.id).count).to eq(0)

    expect(MutedUser.where(user_id: walter.id, muted_user_id: target_user.id).count).to eq(1)
    expect(MutedUser.where(user_id: coding_horror.id, muted_user_id: target_user.id).count).to eq(1)
    expect(MutedUser.where(muted_user_id: source_user.id).count).to eq(0)
  end

  it "merges ignored users" do
    ignored1 = Fabricate(:user)
    ignored2 = Fabricate(:user)
    ignored3 = Fabricate(:user)

    Fabricate(:ignored_user, user: source_user, ignored_user: ignored1)
    Fabricate(:ignored_user, user: source_user, ignored_user: ignored2)
    Fabricate(:ignored_user, user: target_user, ignored_user: ignored2)
    Fabricate(:ignored_user, user: target_user, ignored_user: ignored3)
    Fabricate(:ignored_user, user: walter, ignored_user: source_user)
    Fabricate(:ignored_user, user: coding_horror, ignored_user: source_user)
    Fabricate(:ignored_user, user: coding_horror, ignored_user: target_user)

    merge_users!

    [ignored1, ignored2, ignored3].each do |m|
      expect(IgnoredUser.where(user_id: target_user.id, ignored_user_id: m.id).count).to eq(1)
    end
    expect(IgnoredUser.where(user_id: source_user.id).count).to eq(0)

    expect(IgnoredUser.where(user_id: walter.id, ignored_user_id: target_user.id).count).to eq(1)
    expect(IgnoredUser.where(user_id: coding_horror.id, ignored_user_id: target_user.id).count).to eq(1)
    expect(IgnoredUser.where(ignored_user_id: source_user.id).count).to eq(0)
  end

  context "notifications" do
    it "updates notifications" do
      Fabricate(:notification, user: source_user)
      Fabricate(:notification, user: source_user)
      Fabricate(:notification, user: walter)

      merge_users!

      expect(Notification.where(user_id: target_user.id).count).to eq(2)
      expect(Notification.where(user_id: source_user.id).count).to eq(0)
    end
  end

  context "post actions" do
    it "merges post actions" do
      type_ids = PostActionType.public_type_ids + [PostActionType.flag_types.values.first]

      type_ids.each do |type|
        PostActionCreator.new(source_user, p1, type).perform
        PostActionCreator.new(source_user, p2, type).perform
        PostActionCreator.new(target_user, p2, type).perform
        PostActionCreator.new(target_user, p3, type).perform
      end

      merge_users!

      type_ids.each do |type|
        expect(PostAction.where(user_id: target_user.id, post_action_type_id: type)
                 .pluck(:post_id)).to contain_exactly(p1.id, p2.id, p3.id)
      end

      expect(PostAction.where(user_id: source_user.id).count).to eq(0)
    end

    it "updates post actions" do
      action1 = PostActionCreator.create(source_user, p1, :off_topic).post_action
      action1.update_attribute(:deleted_by_id, source_user.id)

      action2 = PostActionCreator.create(source_user, p2, :off_topic).post_action
      action2.update_attribute(:deferred_by_id, source_user.id)

      action3 = PostActionCreator.create(source_user, p3, :off_topic).post_action
      action3.update_attribute(:agreed_by_id, source_user.id)

      action4 = PostActionCreator.create(source_user, p4, :off_topic).post_action
      action4.update_attribute(:disagreed_by_id, source_user.id)

      merge_users!

      expect(action1.reload.deleted_by_id).to eq(target_user.id)
      expect(action2.reload.deferred_by_id).to eq(target_user.id)
      expect(action3.reload.agreed_by_id).to eq(target_user.id)
      expect(action4.reload.disagreed_by_id).to eq(target_user.id)
    end
  end

  it "updates post revisions" do
    post = p1
    post_revision = Fabricate(:post_revision, post: post, user: source_user)

    merge_users!
    expect(post_revision.reload.user).to eq(target_user)
  end

  context "post timings" do
    def create_post_timing(post, user, msecs)
      PostTiming.create!(
        topic_id: post.topic_id,
        post_number: post.post_number,
        user_id: user.id,
        msecs: msecs
      )
    end

    def post_timing_msecs_for(post, user)
      PostTiming.where(
        topic_id: post.topic_id,
        post_number: post.post_number,
        user_id: user.id
      ).pluck(:msecs)[0] || 0
    end

    it "merges post timings" do
      post1 = p1
      post2 = p2
      post3 = p3
      post4 = p4

      create_post_timing(post1, source_user, 12345)
      create_post_timing(post2, source_user, 9876)
      create_post_timing(post4, source_user, 2**31 - 100)
      create_post_timing(post2, target_user, 3333)
      create_post_timing(post3, target_user, 10000)
      create_post_timing(post4, target_user, 5000)

      merge_users!

      expect(post_timing_msecs_for(post1, target_user)).to eq(12345)
      expect(post_timing_msecs_for(post2, target_user)).to eq(13209)
      expect(post_timing_msecs_for(post3, target_user)).to eq(10000)
      expect(post_timing_msecs_for(post4, target_user)).to eq(2**31 - 1)

      expect(PostTiming.where(user_id: source_user.id).count).to eq(0)
    end
  end

  context "posts" do
    it "updates user ids of posts" do
      source_user.update_attribute(:moderator, true)

      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic, user: source_user)

      post2 = Fabricate(:basic_reply, topic: topic, user: walter)
      post2.revise(source_user, raw: "#{post2.raw} foo")
      PostLocker.new(post2, source_user).lock
      post2.trash!(source_user)

      merge_users!
      post2.reload

      expect(post2.deleted_by).to eq(target_user)
      expect(post2.last_editor).to eq(target_user)
      expect(post2.locked_by_id).to eq(target_user.id)
      expect(post2.reply_to_user).to eq(target_user)
    end

    it "updates post action counts" do
      posts = {}

      PostActionType.types.each do |type_name, type_id|
        posts[type_name] = post = Fabricate(:post, user: walter)
        PostActionCreator.new(source_user, post, type_id).perform
        PostActionCreator.new(target_user, post, type_id).perform
      end

      merge_users!

      posts.each do |type, post|
        post.reload
        expect(post.public_send("#{type}_count")).to eq(1)
      end
    end
  end

  it "updates reviewables and reviewable history" do
    reviewable = Fabricate(:reviewable_queued_post, created_by: source_user)

    merge_users!

    expect(reviewable.reload.created_by).to eq(target_user)
    expect(reviewable.reviewable_histories.first.created_by).to eq(target_user)
  end

  describe 'search logs' do
    after do
      SearchLog.clear_debounce_cache!
    end

    it "updates search log entries" do
      SearchLog.log(term: 'hello', search_type: :full_page, ip_address: '192.168.0.1', user_id: source_user.id)
      SearchLog.log(term: 'world', search_type: :full_page, ip_address: '192.168.0.1', user_id: source_user.id)
      SearchLog.log(term: 'star trek', search_type: :full_page, ip_address: '192.168.0.2', user_id: target_user.id)
      SearchLog.log(term: 'bad', search_type: :full_page, ip_address: '192.168.0.3', user_id: walter.id)

      merge_users!

      expect(SearchLog.where(user_id: target_user.id).count).to eq(3)
      expect(SearchLog.where(user_id: source_user.id).count).to eq(0)
      expect(SearchLog.where(user_id: walter.id).count).to eq(1)
    end
  end

  it "merges tag notification settings" do
    tag1 = Fabricate(:tag)
    tag2 = Fabricate(:tag)
    tag3 = Fabricate(:tag)
    watching = TagUser.notification_levels[:watching]

    TagUser.batch_set(source_user, :watching, [tag1.name, tag2.name])
    TagUser.batch_set(target_user, :watching, [tag2.name, tag3.name])

    merge_users!

    tag_ids = TagUser.where(user_id: target_user.id, notification_level: watching).pluck(:tag_id)
    expect(tag_ids).to contain_exactly(tag1.id, tag2.id, tag3.id)

    tag_ids = TagUser.where(user_id: source_user.id, notification_level: watching).pluck(:tag_id)
    expect(tag_ids).to be_empty
  end

  it "updates themes" do
    theme = Fabricate(:theme, user: source_user)
    merge_users!

    expect(theme.reload.user_id).to eq(target_user.id)
  end

  it "merges allowed users for topics" do
    pm_topic1 = Fabricate(:private_message_topic, topic_allowed_users: [
      Fabricate.build(:topic_allowed_user, user: target_user),
      Fabricate.build(:topic_allowed_user, user: walter),
      Fabricate.build(:topic_allowed_user, user: source_user)
    ])

    pm_topic2 = Fabricate(:private_message_topic, topic_allowed_users: [
      Fabricate.build(:topic_allowed_user, user: walter),
      Fabricate.build(:topic_allowed_user, user: source_user)
    ])

    merge_users!

    expect(pm_topic1.allowed_users).to contain_exactly(target_user, walter)
    expect(pm_topic2.allowed_users).to contain_exactly(target_user, walter)
    expect(TopicAllowedUser.where(user_id: source_user.id).count).to eq(0)
  end

  it "updates topic embeds" do
    topic_embed = Fabricate(:topic_embed, embed_url: "http://example.com/post/248")
    topic_embed.trash!(source_user)

    merge_users!

    expect(topic_embed.reload.deleted_by).to eq(target_user)
  end

  it "updates topic links" do
    topic = Fabricate(:topic, user: source_user)
    post = Fabricate(:post_with_external_links, user: source_user, topic: topic)
    TopicLink.extract_from(post)
    link = topic.topic_links.first

    TopicLinkClick.create!(topic_link_id: link.id, user_id: source_user.id, ip_address: '127.0.0.1')
    TopicLinkClick.create!(topic_link_id: link.id, user_id: target_user.id, ip_address: '127.0.0.1')
    TopicLinkClick.create!(topic_link_id: link.id, user_id: walter.id, ip_address: '127.0.0.1')

    merge_users!

    expect(TopicLink.where(user_id: target_user.id).count).to be > 0
    expect(TopicLink.where(user_id: source_user.id).count).to eq(0)

    expect(TopicLinkClick.where(user_id: target_user.id).count).to eq(2)
    expect(TopicLinkClick.where(user_id: source_user.id).count).to eq(0)
    expect(TopicLinkClick.where(user_id: walter.id).count).to eq(1)
  end

  context "topic timers" do
    def create_topic_timer(topic, user, status_type, deleted_by = nil)
      timer = Fabricate(:topic_timer, topic: topic, user: user, status_type: TopicTimer.types[status_type])
      timer.trash!(deleted_by) if deleted_by
      timer.reload
    end

    it "merges topic timers" do
      topic1 = Fabricate(:topic)
      timer1 = create_topic_timer(topic1, source_user, :close, Discourse.system_user)
      timer2 = create_topic_timer(topic1, source_user, :close)
      timer3 = create_topic_timer(topic1, source_user, :reminder, source_user)
      timer4 = create_topic_timer(topic1, target_user, :reminder, target_user)
      timer5 = create_topic_timer(topic1, source_user, :reminder)

      topic2 = Fabricate(:topic)
      timer6 = create_topic_timer(topic2, target_user, :close)
      timer7 = create_topic_timer(topic2, target_user, :reminder, Discourse.system_user)
      create_topic_timer(topic2, source_user, :reminder, Discourse.system_user)

      merge_users!

      [timer1, timer2, timer3, timer4, timer5, timer6, timer7].each do |t|
        expect(t.reload.user).to eq(target_user)
      end

      expect(TopicTimer.with_deleted.where(user_id: source_user.id).count).to eq(0)
      expect(TopicTimer.with_deleted.where(deleted_by_id: target_user.id).count).to eq(2)
      expect(TopicTimer.with_deleted.where(deleted_by_id: source_user.id).count).to eq(0)
    end
  end

  it "merges topic notification settings" do
    topic1 = Fabricate(:topic)
    topic2 = Fabricate(:topic)
    topic3 = Fabricate(:topic)
    watching = TopicUser.notification_levels[:watching]

    Fabricate(:topic_user, notification_level: watching, topic: topic1, user: source_user)
    Fabricate(:topic_user, notification_level: watching, topic: topic2, user: source_user)
    Fabricate(:topic_user, notification_level: watching, topic: topic2, user: target_user)
    Fabricate(:topic_user, notification_level: watching, topic: topic3, user: target_user)

    merge_users!

    topic_ids = TopicUser.where(user_id: target_user.id, notification_level: watching).pluck(:topic_id)
    expect(topic_ids).to contain_exactly(topic1.id, topic2.id, topic3.id)

    topic_ids = TopicUser.where(user_id: source_user.id, notification_level: watching).pluck(:topic_id)
    expect(topic_ids).to be_empty
  end

  it "merges topic views" do
    topic1 = Fabricate(:topic)
    topic2 = Fabricate(:topic)
    topic3 = Fabricate(:topic)
    ip = '127.0.0.1'

    TopicViewItem.add(topic1.id, ip, source_user.id)
    TopicViewItem.add(topic2.id, ip, source_user.id)
    TopicViewItem.add(topic2.id, ip, target_user.id)
    TopicViewItem.add(topic3.id, ip, target_user.id)

    merge_users!

    topic_ids = TopicViewItem.where(user_id: target_user.id).pluck(:topic_id)
    expect(topic_ids).to contain_exactly(topic1.id, topic2.id, topic3.id)
    expect(TopicViewItem.where(user_id: source_user.id).count).to eq(0)
  end

  it "updates topics" do
    topic = Fabricate(:topic)
    Fabricate(:post, user: walter, topic: topic)
    Fabricate(:post, user: source_user, topic: topic)
    topic.trash!(source_user)

    merge_users!
    topic.reload

    expect(topic.deleted_by).to eq(target_user)
    expect(topic.last_poster).to eq(target_user)
  end

  it "updates unsubscribe keys" do
    UnsubscribeKey.create_key_for(source_user, "digest")
    UnsubscribeKey.create_key_for(target_user, "digest")
    UnsubscribeKey.create_key_for(walter, "digest")

    merge_users!

    expect(UnsubscribeKey.where(user_id: target_user.id).count).to eq(2)
    expect(UnsubscribeKey.where(user_id: source_user.id).count).to eq(0)
  end

  it "updates uploads" do
    Fabricate(:upload, user: source_user)
    Fabricate(:upload, user: target_user)
    Fabricate(:upload, user: walter)

    merge_users!

    expect(Upload.where(user_id: target_user.id).count).to eq(2)
    expect(Upload.where(user_id: source_user.id).count).to eq(0)
  end

  context "user actions" do
    # action_type and user_id are not nullable
    # target_topic_id and acting_user_id are nullable, but always have a value

    fab!(:post1) { p1 }
    fab!(:post2) { p2 }

    def log_like_action(acting_user, user, post)
      UserAction.log_action!(action_type: UserAction::LIKE,
                             user_id: user.id,
                             acting_user_id: acting_user.id,
                             target_topic_id: post.topic_id,
                             target_post_id: post.id)
    end

    def log_got_private_message(acting_user, user, topic)
      UserAction.log_action!(action_type: UserAction::GOT_PRIVATE_MESSAGE,
                             user_id: user.id,
                             acting_user_id: acting_user.id,
                             target_topic_id: topic.id,
                             target_post_id: -1)
    end

    it "merges when target_post_id is set" do
      _a1 = log_like_action(source_user, walter, post1)
      a2 = log_like_action(target_user, walter, post1)
      a3 = log_like_action(source_user, walter, post2)

      merge_users!

      expect(UserAction.count).to eq(2)

      action_ids = UserAction.where(action_type: UserAction::LIKE,
                                    user_id: walter.id,
                                    acting_user_id: target_user.id).pluck(:id)
      expect(action_ids).to contain_exactly(a2.id, a3.id)
    end

    it "merges when acting_user is neither source_user nor target_user" do
      pm_topic1 = Fabricate(:private_message_topic, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: walter),
        Fabricate.build(:topic_allowed_user, user: source_user),
        Fabricate.build(:topic_allowed_user, user: target_user),
        Fabricate.build(:topic_allowed_user, user: coding_horror),
      ])

      pm_topic2 = Fabricate(:private_message_topic, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: walter),
        Fabricate.build(:topic_allowed_user, user: source_user)
      ])

      pm_topic3 = Fabricate(:private_message_topic, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: walter),
        Fabricate.build(:topic_allowed_user, user: target_user)
      ])

      _a1 = log_got_private_message(walter, source_user, pm_topic1)
      a2 = log_got_private_message(walter, target_user, pm_topic1)
      _a3 = log_got_private_message(walter, coding_horror, pm_topic1)
      a4 = log_got_private_message(walter, source_user, pm_topic2)
      a5 = log_got_private_message(walter, target_user, pm_topic3)

      merge_users!

      expect(UserAction.count).to eq(4)

      action_ids = UserAction.where(action_type: UserAction::GOT_PRIVATE_MESSAGE,
                                    user_id: target_user.id,
                                    acting_user_id: walter.id).pluck(:id)
      expect(action_ids).to contain_exactly(a2.id, a4.id, a5.id)
    end
  end

  it "merges archived messages" do
    pm_topic1 = Fabricate(:private_message_topic, topic_allowed_users: [
      Fabricate.build(:topic_allowed_user, user: target_user),
      Fabricate.build(:topic_allowed_user, user: walter),
      Fabricate.build(:topic_allowed_user, user: source_user)
    ])

    pm_topic2 = Fabricate(:private_message_topic, topic_allowed_users: [
      Fabricate.build(:topic_allowed_user, user: walter),
      Fabricate.build(:topic_allowed_user, user: source_user)
    ])

    UserArchivedMessage.archive!(source_user.id, pm_topic1)
    UserArchivedMessage.archive!(target_user.id, pm_topic1)
    UserArchivedMessage.archive!(source_user.id, pm_topic2)
    UserArchivedMessage.archive!(walter.id, pm_topic2)

    merge_users!

    topic_ids = UserArchivedMessage.where(user_id: target_user.id).pluck(:topic_id)
    expect(topic_ids).to contain_exactly(pm_topic1.id, pm_topic2.id)
    expect(UserArchivedMessage.where(user_id: source_user.id).count).to eq(0)
  end

  context "badges" do
    def create_badge(badge, user, opts = {})
      UserBadge.create!(
        badge: badge,
        user: user,
        granted_by: opts[:granted_by] || Discourse.system_user,
        granted_at: opts[:granted_at] || Time.now,
        post: opts[:post],
        seq: opts[:seq] || 0
      )
    end

    it "merges user badges" do
      anniversary_badge = Badge.find(Badge::Anniversary)
      create_badge(anniversary_badge, source_user, seq: 1)
      b1 = create_badge(anniversary_badge, target_user, seq: 1)
      b2 = create_badge(anniversary_badge, source_user, seq: 2)

      great_post_badge = Badge.find(Badge::GreatPost)
      b3 = create_badge(great_post_badge, target_user, post: Fabricate(:post, user: target_user))
      b4 = create_badge(great_post_badge, source_user, post: Fabricate(:post, user: source_user))

      autobiographer_badge = Badge.find(Badge::Autobiographer)
      b5 = create_badge(autobiographer_badge, source_user)

      merge_users!

      user_badge_ids = UserBadge.where(user_id: target_user.id).pluck(:id)
      expect(user_badge_ids).to contain_exactly(b1.id, b2.id, b3.id, b4.id, b5.id)
      expect(UserBadge.where(user_id: source_user.id).count).to eq(0)
    end

    it "updates granted_by for user badges" do
      badge = Badge.create!(name: 'Hero', badge_type_id: BadgeType::Gold)
      user_badge = create_badge(badge, walter, seq: 1, granted_by: source_user)

      merge_users!

      expect(user_badge.reload.granted_by).to eq(target_user)
    end
  end

  it "merges user custom fields" do
    UserCustomField.create!(user_id: source_user.id, name: 'foo', value: '123')
    UserCustomField.create!(user_id: source_user.id, name: 'bar', value: '456')
    UserCustomField.create!(user_id: source_user.id, name: 'duplicate', value: 'source')
    UserCustomField.create!(user_id: target_user.id, name: 'duplicate', value: 'target')
    UserCustomField.create!(user_id: target_user.id, name: 'baz', value: '789')

    merge_users!

    fields = UserCustomField.where(user_id: target_user.id).pluck(:name, :value)
    expect(fields).to contain_exactly(['foo', '123'], ['bar', '456'], ['duplicate', 'target'], ['baz', '789'])
    expect(UserCustomField.where(user_id: source_user.id).count).to eq(0)
  end

  it "merges email addresses" do
    merge_users!

    emails = UserEmail.where(user_id: target_user.id).pluck(:email, :primary)
    expect(emails).to contain_exactly(['alice@example.com', true], ['alice@work.com', false])
    expect(UserEmail.where(user_id: source_user.id).count).to eq(0)
  end

  it "skips merging email addresses when a secondary email address exists" do
    merge_users!(source_user, target_user)

    alice2 = Fabricate(:user, username: 'alice2', email: 'alice@foo.com')
    merge_users!(alice2, target_user)

    emails = UserEmail.where(user_id: target_user.id).pluck(:email, :primary)
    expect(emails).to contain_exactly(['alice@example.com', true], ['alice@work.com', false])
    expect(UserEmail.where(user_id: source_user.id).count).to eq(0)
  end

  it "skips merging email addresses when target user is not human" do
    target_user = Discourse.system_user
    merge_users!(source_user, target_user)

    emails = UserEmail.where(user_id: target_user.id).pluck(:email, :primary)
    expect(emails).to contain_exactly([target_user.email, true])
    expect(UserEmail.exists?(user_id: source_user.id)).to eq(false)
  end

  it "updates exports" do
    UserExport.create(file_name: "user-archive-alice1-190218-003249", user_id: source_user.id)

    merge_users!

    expect(UserExport.where(user_id: target_user.id).count).to eq(1)
    expect(UserExport.where(user_id: source_user.id).count).to eq(0)
  end

  it "updates user history" do
    UserHistory.create(action: UserHistory.actions[:notified_about_get_a_room], target_user_id: source_user.id)
    UserHistory.create(action: UserHistory.actions[:anonymize_user], target_user_id: walter.id, acting_user_id: source_user.id)

    merge_users!
    UserHistory.where(action: UserHistory.actions[:merge_user], target_user_id: target_user.id).delete_all

    expect(UserHistory.where(target_user_id: target_user.id).count).to eq(1)
    expect(UserHistory.where(target_user_id: source_user.id).count).to eq(0)

    expect(UserHistory.where(acting_user_id: target_user.id).count).to eq(1)
    expect(UserHistory.where(acting_user_id: source_user.id).count).to eq(0)
  end

  it "updates user profile views" do
    ip = '127.0.0.1'
    UserProfileView.add(source_user.id, ip, walter.id, Time.now, true)
    UserProfileView.add(source_user.id, ip, target_user.id, Time.now, true)
    UserProfileView.add(target_user.id, ip, source_user.id, Time.now, true)
    UserProfileView.add(walter.id, ip, source_user.id, Time.now, true)

    merge_users!

    expect(UserProfileView.where(user_profile_id: target_user.id).count).to eq(3)
    expect(UserProfileView.where(user_profile_id: walter.id).count).to eq(1)
    expect(UserProfileView.where(user_profile_id: source_user.id).count).to eq(0)

    expect(UserProfileView.where(user_id: target_user.id).count).to eq(3)
    expect(UserProfileView.where(user_id: walter.id).count).to eq(1)
    expect(UserProfileView.where(user_id: source_user.id).count).to eq(0)
  end

  it "merges user visits" do
    freeze_time DateTime.parse('2010-01-01 12:00')

    UserVisit.create!(user_id: source_user.id, visited_at: 2.days.ago, posts_read: 22, mobile: false, time_read: 400)
    UserVisit.create!(user_id: source_user.id, visited_at: Date.yesterday, posts_read: 8, mobile: false, time_read: 100)
    UserVisit.create!(user_id: target_user.id, visited_at: Date.yesterday, posts_read: 12, mobile: true, time_read: 270)
    UserVisit.create!(user_id: target_user.id, visited_at: Date.today, posts_read: 10, mobile: true, time_read: 150)

    merge_users!

    expect(UserVisit.where(user_id: target_user.id).count).to eq(3)
    expect(UserVisit.where(user_id: source_user.id).count).to eq(0)

    expect(UserVisit.where(user_id: target_user.id, visited_at: 2.days.ago, posts_read: 22, mobile: false, time_read: 400).count).to eq(1)
    expect(UserVisit.where(user_id: target_user.id, visited_at: Date.yesterday, posts_read: 20, mobile: true, time_read: 370).count).to eq(1)
    expect(UserVisit.where(user_id: target_user.id, visited_at: Date.today, posts_read: 10, mobile: true, time_read: 150).count).to eq(1)
  end

  it "updates user warnings" do
    UserWarning.create!(topic: Fabricate(:topic), user: source_user, created_by: walter)
    UserWarning.create!(topic: Fabricate(:topic), user: target_user, created_by: walter)
    UserWarning.create!(topic: Fabricate(:topic), user: walter, created_by: source_user)

    merge_users!

    expect(UserWarning.where(user_id: target_user.id).count).to eq(2)
    expect(UserWarning.where(user_id: source_user.id).count).to eq(0)

    expect(UserWarning.where(created_by_id: target_user.id).count).to eq(1)
    expect(UserWarning.where(created_by_id: source_user.id).count).to eq(0)
  end

  it "triggers :merging_users event" do
    events = DiscourseEvent.track_events do
      merge_users!
    end

    expect(events).to include(event_name: :merging_users, params: [source_user, target_user])
  end

  context "site settings" do
    it "updates usernames in site settings" do
      SiteSetting.site_contact_username = source_user.username
      SiteSetting.embed_by_username = source_user.username

      merge_users!

      expect(SiteSetting.site_contact_username).to eq(target_user.username)
      expect(SiteSetting.embed_by_username).to eq(target_user.username)
    end

    it "updates only the old username in site settings" do
      SiteSetting.site_contact_username = source_user.username
      SiteSetting.embed_by_username = walter.username

      merge_users!

      expect(SiteSetting.site_contact_username).to eq(target_user.username)
      expect(SiteSetting.embed_by_username).to eq(walter.username)
    end
  end

  it "updates users" do
    walter.update!(approved_by: source_user)
    upload = Fabricate(:upload)

    source_user.update!(admin: true)

    source_user.user_profile.update!(
      card_background_upload: upload,
      profile_background_upload: upload,
    )

    merge_users!

    expect(walter.reload.approved_by).to eq(target_user)

    target_user.reload

    expect(target_user.admin).to eq(true)
    expect(target_user.card_background_upload).to eq(upload)
    expect(target_user.profile_background_upload).to eq(upload)
  end

  it "deletes the source user even when it's an admin" do
    source_user.update_attribute(:admin, true)

    expect(User.find_by_username(source_user.username)).to be_present
    merge_users!
    expect(User.find_by_username(source_user.username)).to be_nil
  end

  it "deletes the source user even when it is a member of a group that grants a trust level" do
    group = Fabricate(:group, grant_trust_level: 3)
    group.bulk_add([source_user.id, target_user.id])

    merge_users!

    expect(User.find_by_username(source_user.username)).to be_nil
  end

  it "works even when email domains are restricted" do
    SiteSetting.allowed_email_domains = "example.com|work.com"
    source_user.update_attribute(:admin, true)

    expect(User.find_by_username(source_user.username)).to be_present
    merge_users!
    expect(User.find_by_username(source_user.username)).to be_nil
  end

  it "deletes external auth infos of source user" do
    UserAssociatedAccount.create(user_id: source_user.id, provider_name: "facebook", provider_uid: "1234")
    SingleSignOnRecord.create(user_id: source_user.id, external_id: "example", last_payload: "looks good")

    merge_users!

    expect(UserAssociatedAccount.where(user_id: source_user.id).count).to eq(0)
    expect(SingleSignOnRecord.where(user_id: source_user.id).count).to eq(0)
  end

  it "deletes auth tokens" do
    Fabricate(:api_key, user: source_user)
    Fabricate(:readonly_user_api_key, user: source_user)
    Fabricate(:user_second_factor_totp, user: source_user)

    SiteSetting.verbose_auth_token_logging = true
    UserAuthToken.generate!(user_id: source_user.id, user_agent: "Firefox", client_ip: "127.0.0.1")

    merge_users!

    expect(ApiKey.where(user_id: source_user.id).count).to eq(0)
    expect(UserApiKey.where(user_id: source_user.id).count).to eq(0)
    expect(UserSecondFactor.where(user_id: source_user.id).count).to eq(0)
    expect(UserAuthToken.where(user_id: source_user.id).count).to eq(0)
    expect(UserAuthTokenLog.where(user_id: source_user.id).count).to eq(0)
  end

  it "cleans up all remaining references to the source user" do
    DirectoryItem.refresh!
    Fabricate(:email_change_request, user: source_user)
    Fabricate(:email_token, user: source_user)
    Fabricate(:user_avatar, user: source_user)

    merge_users!

    expect(DirectoryItem.where(user_id: source_user.id).count).to eq(0)
    expect(EmailChangeRequest.where(user_id: source_user.id).count).to eq(0)
    expect(EmailToken.where(user_id: source_user.id).count).to eq(0)
    expect(UserAvatar.where(user_id: source_user.id).count).to eq(0)

    expect(User.find_by_username(source_user.username)).to be_nil
  end

  it "updates the username" do
    Jobs::UpdateUsername.any_instance
      .expects(:execute)
      .with(user_id: source_user.id,
            old_username: 'alice1',
            new_username: 'alice',
            avatar_template: target_user.avatar_template)
      .once

    merge_users!
  end

  it "correctly logs the merge" do
    expect { merge_users! }.to change { UserHistory.count }.by(1)

    log_entry = UserHistory.last
    expect(log_entry.action).to eq(UserHistory.actions[:merge_user])
    expect(log_entry.acting_user_id).to eq(Discourse::SYSTEM_USER_ID)
    expect(log_entry.target_user_id).to eq(target_user.id)
    expect(log_entry.context).to eq(I18n.t("staff_action_logs.user_merged", username: source_user.username))
    expect(log_entry.email).to eq("alice@work.com")
  end
end
