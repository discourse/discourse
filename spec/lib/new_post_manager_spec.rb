# frozen_string_literal: true

require 'rails_helper'
require 'new_post_manager'

describe NewPostManager do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }

  context "default action" do
    it "creates the post by default" do
      manager = NewPostManager.new(user, raw: 'this is a new post', topic_id: topic.id)
      result = manager.perform

      expect(result.action).to eq(:create_post)
      expect(result).to be_success
      expect(result.post).to be_present
      expect(result.post).to be_a(Post)
    end
  end

  context "default action" do
    fab!(:other_user) { Fabricate(:user) }

    it "doesn't enqueue private messages" do
      SiteSetting.approve_unless_trust_level = 4

      manager = NewPostManager.new(user,
                                   raw: 'this is a new post',
                                   title: 'this is a new title',
                                   archetype: Archetype.private_message,
                                   target_usernames: other_user.username)

      result = manager.perform

      expect(result.action).to eq(:create_post)
      expect(result).to be_success
      expect(result.post).to be_present
      expect(result.post.topic.private_message?).to eq(true)
      expect(result.post).to be_a(Post)

      # It doesn't enqueue replies to the private message either
      manager = NewPostManager.new(user,
                                   raw: 'this is a new reply',
                                   topic_id: result.post.topic_id)

      result = manager.perform

      expect(result.action).to eq(:create_post)
      expect(result).to be_success
      expect(result.post).to be_present
      expect(result.post.topic.private_message?).to eq(true)
      expect(result.post).to be_a(Post)
    end

  end

  context "default handler" do
    let(:manager) { NewPostManager.new(user, raw: 'this is new post content', topic_id: topic.id) }

    context 'with the settings zeroed out' do
      before do
        SiteSetting.approve_post_count = 0
        SiteSetting.approve_unless_trust_level = 0
      end

      it "doesn't return a result action" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(false)
        expect(result).to eq(nil)
      end
    end

    context 'basic post/topic count restrictions' do
      before do
        SiteSetting.approve_post_count = 1
      end

      it "works with a correct `user_stat.post_count`" do
        result = NewPostManager.default_handler(manager)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:post_count)

        manager.user.user_stat.update(post_count: 1)
        result = NewPostManager.default_handler(manager)
        expect(result).to eq(nil)
      end

      it "works with a correct `user_stat.topic_count`" do
        result = NewPostManager.default_handler(manager)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:post_count)

        manager.user.user_stat.update(topic_count: 1)
        result = NewPostManager.default_handler(manager)
        expect(result).to eq(nil)
      end
    end

    context 'with a high approval post count and TL0' do
      before do
        SiteSetting.approve_post_count = 100
        topic.user.trust_level = 0
      end
      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:post_count)
      end
    end

    context 'with a high approval post count and TL1' do
      before do
        SiteSetting.approve_post_count = 100
        topic.user.trust_level = 1
      end
      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:post_count)
      end
    end

    context 'with a high approval post count, but TL2' do
      before do
        SiteSetting.approve_post_count = 100
        user.update!(trust_level: 2)
      end

      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(result).to be_nil
      end
    end

    context 'with a high approval post count and secure category' do
      it 'does not create topic' do
        SiteSetting.approve_post_count = 100
        user = Fabricate(:user)
        category_group = Fabricate(:category_group, permission_type: 2)
        Fabricate(:group_user, group: category_group.group, user_id: user.id)

        manager = NewPostManager.new(
          user,
          raw: 'this is a new topic',
          title: "Let's start a new topic!",
          category: category_group.category_id
        )

        expect(manager.perform.errors["base"][0]).to eq(I18n.t("js.errors.reasons.forbidden"))
      end
    end

    context 'with a high trust level setting' do
      before do
        SiteSetting.approve_unless_trust_level = 4
      end
      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:trust_level)
      end
    end

    context "with uncategorized disabled, and approval" do
      before do
        SiteSetting.allow_uncategorized_topics = false
        SiteSetting.approve_unless_trust_level = 4
      end

      it "will return an enqueue result" do
        npm = NewPostManager.new(
          Fabricate(:user),
          title: 'this is a new topic title',
          raw: "this is the raw content",
          category: Fabricate(:category).id
        )

        result = NewPostManager.default_handler(npm)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.errors).to be_blank
      end
    end

    context 'with staged moderation setting enabled' do
      before do
        SiteSetting.approve_unless_staged = true
        user.update!(staged: true)
      end

      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:staged)
      end
    end

    context 'with a high trust level setting for new topics but post responds to existing topic' do
      before do
        SiteSetting.approve_new_topics_unless_trust_level = 4
      end
      it "doesn't return a result action" do
        result = NewPostManager.default_handler(manager)
        expect(result).to eq(nil)
      end
    end

    context 'with a fast typer' do
      before do
        user.update!(trust_level: 0)
      end

      it "adds the silence reason in the system locale" do
        manager = build_manager_with('this is new post content')

        I18n.with_locale(:fr) do # Simulate french user
          result = NewPostManager.default_handler(manager)
        end

        expect(user.silenced?).to eq(true)
        expect(user.silence_reason).to eq(I18n.t("user.new_user_typed_too_fast", locale: :en))
      end

      it 'runs the watched words check before checking if the user is a fast typer' do
        Fabricate(:watched_word, word: "darn", action: WatchedWord.actions[:require_approval])
        manager = build_manager_with('this is darn new post content')

        result = NewPostManager.default_handler(manager)

        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:watched_word)
      end

      def build_manager_with(raw)
        NewPostManager.new(user, raw: raw, topic_id: topic.id, first_post_checks: true)
      end
    end

    context 'with media' do
      let(:manager_opts) do
        {
          raw: 'this is new post content', topic_id: topic.id, first_post_checks: false,
          image_sizes: {
            "http://localhost:3000/uploads/default/original/1X/652fc9667040b1b89dc4d9b061a823ddb3c0cef0.jpeg" => {
              "width" => "500", "height" => "500"
            }
          }
        }
      end

      before do
        user.update!(trust_level: 0)
      end

      it 'queues the post for review because if it contains embedded media.' do
        SiteSetting.review_media_unless_trust_level = 1
        manager = NewPostManager.new(user, manager_opts)

        result = NewPostManager.default_handler(manager)

        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:contains_media)
      end

      it 'does not enqueue the post if the poster is a trusted user' do
        SiteSetting.review_media_unless_trust_level = 0
        manager = NewPostManager.new(user, manager_opts)

        result = NewPostManager.default_handler(manager)

        expect(result).to be_nil
      end
    end
  end

  context "new topic handler" do
    let(:manager) { NewPostManager.new(user, raw: 'this is new topic content', title: 'new topic title') }
    context 'with a high trust level setting for new topics' do
      before do
        SiteSetting.approve_new_topics_unless_trust_level = 4
      end
      it "will return an enqueue result" do
        result = NewPostManager.default_handler(manager)
        expect(NewPostManager.queue_enabled?).to eq(true)
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:new_topics_unless_trust_level)
      end
    end

  end

  context "extensibility priority" do

    after do
      NewPostManager.clear_handlers!
    end

    let(:default_handler) { NewPostManager.method(:default_handler) }

    it "adds in order by default" do
      handler = -> { nil }

      NewPostManager.add_handler(&handler)
      expect(NewPostManager.handlers).to eq([handler])
    end

    it "can be added in high priority" do
      a = -> { nil }
      b = -> { nil }
      c = -> { nil }

      NewPostManager.add_handler(100, &a)
      NewPostManager.add_handler(50, &b)
      NewPostManager.add_handler(101, &c)
      expect(NewPostManager.handlers).to eq([c, a, b])
    end

  end

  context "extensibility" do

    before do
      @counter = 0

      @counter_handler = lambda do |manager|
        result = nil
        if manager.args[:raw] == 'this post increases counter'
          @counter += 1
          result = NewPostResult.new(:counter, true)
        end

        result
      end

      @queue_handler = -> (manager) { manager.args[:raw] =~ /queue me/ ? manager.enqueue('default') : nil }

      NewPostManager.add_handler(&@counter_handler)
      NewPostManager.add_handler(&@queue_handler)
    end

    after do
      NewPostManager.clear_handlers!
    end

    it "has a queue enabled" do
      expect(NewPostManager.queue_enabled?).to eq(true)
    end

    it "calls custom handlers" do
      manager = NewPostManager.new(user, raw: 'this post increases counter', topic_id: topic.id)

      result = manager.perform

      expect(result.action).to eq(:counter)
      expect(result).to be_success
      expect(result.post).to be_blank
      expect(@counter).to be(1)
      expect(Reviewable.list_for(Discourse.system_user).count).to be(0)
    end

    it "calls custom enqueuing handlers" do
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_to_create_tag = 0
      SiteSetting.min_trust_level_to_tag_topics = 0

      manager = NewPostManager.new(
        topic.user,
        raw: 'to the handler I say enqueue me!',
        title: 'this is the title of the queued post',
        tags: ['hello', 'world'],
        category: topic.category_id
      )

      result = manager.perform

      reviewable = result.reviewable

      expect(reviewable).to be_present
      expect(reviewable.payload['title']).to eq('this is the title of the queued post')
      expect(reviewable.reviewable_scores).to be_present
      expect(reviewable.force_review).to eq(true)
      expect(reviewable.reviewable_by_moderator?).to eq(true)
      expect(reviewable.category).to be_present
      expect(reviewable.payload['tags']).to eq(['hello', 'world'])
      expect(result.action).to eq(:enqueued)
      expect(result).to be_success
      expect(result.pending_count).to eq(1)
      expect(result.post).to be_blank
      expect(Reviewable.list_for(Discourse.system_user).count).to eq(1)
      expect(@counter).to be(0)

      reviewable.perform(Discourse.system_user, :approve_post)

      manager = NewPostManager.new(
        topic.user,
        raw: 'another post by this user queue me',
        topic_id: topic.id
      )
      result = manager.perform
      reviewable = result.reviewable

      expect(reviewable.topic).to be_present
      expect(reviewable.category).to be_present
      expect(result.pending_count).to eq(1)
    end

    it "if nothing returns a result it creates a post" do
      manager = NewPostManager.new(user, raw: 'this is a new post', topic_id: topic.id)

      result = manager.perform

      expect(result.action).to eq(:create_post)
      expect(result).to be_success
      expect(result.post).to be_present
      expect(@counter).to be(0)
    end

  end

  context "user needs approval?" do

    let :user do
      user = Fabricate.build(:user, trust_level: 0)
      user_stat = UserStat.new(post_count: 0)
      user.user_stat = user_stat
      user
    end

    it "handles post_needs_approval? correctly" do
      u = user
      default = NewPostManager.new(u, {})
      expect(NewPostManager.post_needs_approval?(default)).to eq(:skip)

      with_check = NewPostManager.new(u, first_post_checks: true)
      expect(NewPostManager.post_needs_approval?(with_check)).to eq(:fast_typer)

      u.user_stat.post_count = 1
      with_check_and_post = NewPostManager.new(u, first_post_checks: true)
      expect(NewPostManager.post_needs_approval?(with_check_and_post)).to eq(:skip)

      u.user_stat.post_count = 0
      u.trust_level = 1
      with_check_tl1 = NewPostManager.new(u, first_post_checks: true)
      expect(NewPostManager.post_needs_approval?(with_check_tl1)).to eq(:skip)
    end
  end

  context 'when posting in the category requires approval' do
    let!(:user) { Fabricate(:user) }
    let!(:review_group) { Fabricate(:group) }
    let!(:category) { Fabricate(:category, reviewable_by_group_id: review_group.id) }

    context 'when new topics require approval' do
      before do
        SiteSetting.tagging_enabled = true
        category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
        category.save
      end

      it 'enqueues new topics' do
        manager = NewPostManager.new(
          user,
          raw: 'this is a new topic',
          title: "Let's start a new topic!",
          category: category.id
        )

        result = manager.perform
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:category)
      end

      it 'does not enqueue the topic when the poster is a category group moderator' do
        SiteSetting.enable_category_group_moderation = true
        review_group.users << user

        manager = NewPostManager.new(
          user,
          raw: 'this is a new topic',
          title: "Let's start a new topic!",
          category: category.id
        )

        result = manager.perform
        expect(result.action).to eq(:create_post)
        expect(result).to be_success
      end

      context "when the category has tagging rules" do
        context "when there is a minimum number of tags required for the category" do
          before do
            category.update(minimum_required_tags: 1)
          end

          it "errors when there are no tags provided" do
            manager = NewPostManager.new(
              user,
              raw: 'this is a new topic',
              title: "Let's start a new topic!",
              category: category.id
            )

            result = manager.perform
            expect(result.action).to eq(:enqueued)
            expect(result.errors.full_messages).to include(I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
          end

          it "enqueues the topic if there are tags provided" do
            tag = Fabricate(:tag)
            manager = NewPostManager.new(
              user,
              raw: 'this is a new topic',
              title: "Let's start a new topic!",
              category: category.id,
              tags: tag.name
            )

            result = manager.perform
            expect(result.action).to eq(:enqueued)
            expect(result.reason).to eq(:category)
          end
        end

        context "when there is a minimum number of tags required from a certain tag group for the category" do
          let(:tag_group) { Fabricate(:tag_group) }
          let(:tag) { Fabricate(:tag) }
          before do
            TagGroupMembership.create(tag: tag, tag_group: tag_group)
            category.update(min_tags_from_required_group: 1, required_tag_group_id: tag_group.id)
          end

          it "errors when there are no tags from the group provided" do
            manager = NewPostManager.new(
              user,
              raw: 'this is a new topic',
              title: "Let's start a new topic!",
              category: category.id
            )

            result = manager.perform
            expect(result.action).to eq(:enqueued)
            expect(result.errors.full_messages).to include(
              I18n.t(
                "tags.required_tags_from_group",
                count: category.min_tags_from_required_group,
                tag_group_name: category.required_tag_group.name,
                tags: tag.name
              )
            )
          end

          it "enqueues the topic if there are tags provided" do
            manager = NewPostManager.new(
              user,
              raw: 'this is a new topic',
              title: "Let's start a new topic!",
              category: category.id,
              tags: [tag.name]
            )

            result = manager.perform
            expect(result.action).to eq(:enqueued)
            expect(result.reason).to eq(:category)
          end
        end
      end
    end

    context 'when new posts require approval' do
      let!(:topic) { Fabricate(:topic, category: category) }

      before do
        category.custom_fields[Category::REQUIRE_REPLY_APPROVAL] = true
        category.save
      end

      it 'enqueues new posts' do
        manager = NewPostManager.new(user, raw: 'this is a new post', topic_id: topic.id)

        result = manager.perform
        expect(result.action).to eq(:enqueued)
        expect(result.reason).to eq(:category)
      end

      it "doesn't blow up with invalid topic_id" do
        expect do
          manager = NewPostManager.new(
            user,
            raw: 'this is a new topic',
            topic_id: 97546
          )
          expect(manager.perform.action).to eq(:create_post)
        end.not_to raise_error
      end

      it 'does not enqueue the post when the poster is a category group moderator' do
        SiteSetting.enable_category_group_moderation = true
        review_group.users << user

        manager = NewPostManager.new(
          user,
          raw: 'this is a new post',
          topic_id: topic.id
        )

        result = manager.perform
        expect(result.action).to eq(:create_post)
        expect(result).to be_success
      end
    end
  end

  context "via email" do
    let(:manager) do
      NewPostManager.new(
        topic.user,
        raw: 'this is emailed content',
        topic_id: topic.id,
        via_email: true,
        raw_email: 'raw email contents'
      )
    end

      before do
        SiteSetting.approve_post_count = 100
        topic.user.trust_level = 0
      end

    it "will store via_email and raw_email in the enqueued post" do
      result = manager.perform
      expect(result.action).to eq(:enqueued)
      expect(result.reviewable).to be_present
      expect(result.reviewable.payload['via_email']).to eq(true)
      expect(result.reviewable.payload['raw_email']).to eq('raw email contents')

      post = result.reviewable.perform(Discourse.system_user, :approve_post).created_post
      expect(post.via_email).to eq(true)
      expect(post.raw_email).to eq("raw email contents")
    end
  end

  context "via email with a spam failure" do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    it "silences users if its their first post" do
      manager = NewPostManager.new(
        user,
        raw: 'this is emailed content',
        via_email: true,
        raw_email: 'raw email contents',
        email_spam: true,
        first_post_checks: true
      )

      result = manager.perform
      expect(result.action).to eq(:enqueued)
      expect(user.silenced?).to be(true)
    end

    it "doesn't silence or enqueue exempt users" do
      manager = NewPostManager.new(
        admin,
        raw: 'this is emailed content',
        via_email: true,
        raw_email: 'raw email contents',
        email_spam: true,
        first_post_checks: true
      )

      result = manager.perform
      expect(result.action).to eq(:create_post)
      expect(admin.silenced?).to be(false)
    end
  end

  context "via email with an authentication results failure" do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    it "doesn't silence users" do
      manager = NewPostManager.new(
        user,
        raw: 'this is emailed content',
        via_email: true,
        raw_email: 'raw email contents',
        email_auth_res_action: :enqueue,
        first_post_checks: true
      )

      result = manager.perform
      expect(result.action).to eq(:enqueued)
      expect(user.silenced?).to be(false)
    end

    it "still enqueues exempt users" do
      manager = NewPostManager.new(
        admin,
        raw: 'this is emailed content',
        via_email: true,
        raw_email: 'raw email contents',
        email_auth_res_action: :enqueue
      )

      result = manager.perform
      expect(result.action).to eq(:enqueued)
      expect(user.silenced?).to be(false)
    end
  end

  context "private message via email" do
    it "doesn't enqueue authentication results failure" do
      manager = NewPostManager.new(
        topic.user,
        raw: 'this is emailed content',
        archetype: Archetype.private_message,
        via_email: true,
        raw_email: 'raw email contents',
        email_auth_res_action: :enqueue
      )

      result = manager.perform
      expect(result.action).to eq(:create_post)
    end

    it "doesn't enqueue spam failure" do
      manager = NewPostManager.new(
        topic.user,
        raw: 'this is emailed content',
        archetype: Archetype.private_message,
        via_email: true,
        raw_email: 'raw email contents',
        email_spam: true
      )

      result = manager.perform
      expect(result.action).to eq(:create_post)
    end
  end

end
