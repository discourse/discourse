# frozen_string_literal: true

require "post_creator"
require "topic_subtype"

RSpec.describe PostCreator, "#create" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }
  fab!(:evil_trout) { Fabricate(:evil_trout, refresh_auto_groups: true) }
  let(:topic) { Fabricate(:topic, user: user) }

  fab!(:category) { Fabricate(:category, user: user) }
  let(:basic_topic_params) do
    {
      title: "hello world topic",
      raw: "my name is fred",
      archetype_id: 1,
      advance_draft: true,
      writing_device: "linux",
      user_agent:
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
      composer_version: 2,
    }
  end
  let(:image_sizes) do
    { "http://an.image.host/image.jpg" => { "width" => 111, "height" => 222 } }
  end

  let(:creator) { PostCreator.new(user, basic_topic_params) }
  let(:creator_with_category) do
    PostCreator.new(user, basic_topic_params.merge(category: category.id))
  end
  let(:creator_with_image_sizes) do
    PostCreator.new(user, basic_topic_params.merge(image_sizes: image_sizes))
  end
  let(:creator_with_featured_link) do
    PostCreator.new(
      user,
      title: "featured link topic",
      archetype_id: 1,
      featured_link: "http://www.discourse.org",
      raw: "http://www.discourse.org",
    )
  end

  it "can create a topic with null byte central" do
    post =
      PostCreator.create(
        user,
        title: "hello\u0000world this is title",
        raw: "this is my\u0000 first topic",
      )
    expect(post.raw).to eq "this is my first topic"
    expect(post.topic.title).to eq "Helloworld this is title"
  end

  it "can be created with auto tracking disabled" do
    p = PostCreator.create(user, basic_topic_params.merge(auto_track: false))
    # must be 0 otherwise it will think we read the topic which is clearly untrue
    expect(TopicUser.where(user_id: p.user_id, topic_id: p.topic_id).count).to eq(0)
  end

  it "can be created with first post as wiki" do
    cat = Fabricate(:category)
    cat.all_topics_wiki = true
    cat.save
    post = PostCreator.create(user, basic_topic_params.merge(category: cat.id))
    expect(post.wiki).to eq(true)
  end

  it "creates post with a hidden reason for staff user" do
    hri = Post.hidden_reasons[:flag_threshold_reached]
    post = PostCreator.create(admin, basic_topic_params.merge(hidden_reason_id: hri))
    expect(post.hidden).to eq(true)
    expect(post.hidden_at).to be_present
    expect(post.hidden_reason_id).to eq(hri)
    expect(post.topic.visible).to eq(false)
    expect(post.user.topic_count).to eq(0)
    expect(post.user.post_count).to eq(0)
  end

  it "fails to create post with a hidden reason for non-staff user" do
    hri = Post.hidden_reasons[:flag_threshold_reached]

    expect do
      post = PostCreator.create(user, basic_topic_params.merge(hidden_reason_id: hri))

      expect(post).to be_nil
    end.not_to change { Post.count }
  end

  it "ensures the user can create the topic" do
    Guardian.any_instance.expects(:can_create?).with(Topic, nil).returns(false)
    expect { creator.create }.to raise_error(Discourse::InvalidAccess)
  end

  it "can be created with custom fields" do
    post =
      PostCreator.create(
        user,
        basic_topic_params.merge(topic_opts: { custom_fields: { hello: "world" } }),
      )

    expect(post.topic.custom_fields).to eq("hello" => "world")
  end

  context "with reply to post number" do
    it "omits reply to post number if received on a new topic" do
      p = PostCreator.new(user, basic_topic_params.merge(reply_to_post_number: 3)).create
      expect(p.reply_to_post_number).to be_nil
    end
  end

  context "with invalid title" do
    let(:creator_invalid_title) { PostCreator.new(user, basic_topic_params.merge(title: "a")) }

    it "has errors" do
      creator_invalid_title.create
      expect(creator_invalid_title.errors).to be_present
    end
  end

  context "with invalid raw" do
    let(:creator_invalid_raw) { PostCreator.new(user, basic_topic_params.merge(raw: "")) }

    it "has errors" do
      creator_invalid_raw.create
      expect(creator_invalid_raw.errors).to be_present
    end
  end

  context "with success" do
  before { creator }

  it "is not hidden" do
    p = creator.create
    expect(p.hidden).to eq(false)
    expect(p.hidden_at).not_to be_present
    expect(p.hidden_reason_id).to eq(nil)
    expect(p.topic.visible).to eq(true)
  end

  it "doesn't return true for spam" do
    creator.create
    expect(creator.spam?).to eq(false)
  end

  it "triggers extensibility events" do
    events = DiscourseEvent.track_events { creator.create }

    expect(events.map { |event| event[:event_name] }).to include(
      :before_create_post,
      :validate_post,
      :topic_created,
      :post_created,
      :after_validate_topic,
      :before_create_topic,
      :after_trigger_post_process,
      :markdown_context,
      :topic_notification_level_changed,
    )
  end

  it "before_create_post event signature contains both post and opts" do
    events = DiscourseEvent.track_events { creator.create }

    expect(events).to include(
      event_name: :before_create_post,
      params: [creator.post, creator.opts],
    )
  end

  it "does not notify on system messages" do
    messages =
      MessageBus.track_publish do
        p =
          PostCreator.create(
            admin,
            basic_topic_params.merge(post_type: Post.types[:moderator_action]),
          )
        PostCreator.create(
          admin,
          basic_topic_params.merge(
            topic_id: p.topic_id,
            post_type: Post.types[:moderator_action],
          ),
        )
      end
    # don't notify on system messages they introduce too much noise
    channels = messages.map(&:channel)
    expect(channels.find { |s| s =~ /unread/ }).to eq(nil)
    expect(channels.find { |s| s =~ /new/ }).to eq(nil)
  end

  it "enqueues job to generate messages" do
    p = creator.create
    expect(
      job_enqueued?(job: :post_update_topic_tracking_state, args: { post_id: p.id }),
    ).to eq(true)
  end

  it "generates the correct messages for a secure topic" do
    Jobs.run_immediately!
    UserActionManager.enable

    admin = Fabricate(:user, refresh_auto_groups: true)
    admin.grant_admin!
    other_admin = Fabricate(:user, refresh_auto_groups: true)
    other_admin.grant_admin!

    cat = Fabricate(:category)
    cat.set_permissions(admins: :full)
    cat.save

    created_post = nil

    messages =
      MessageBus.track_publish do
        created_post = PostCreator.new(admin, basic_topic_params.merge(category: cat.id)).create
        Fabricate(:topic_user_tracking, topic: created_post.topic, user: other_admin)
        _reply =
          PostCreator.new(
            admin,
            raw: "this is my test reply 123 testing",
            topic_id: created_post.topic_id,
            advance_draft: true,
          ).create
      end

    messages.filter! { |m| m.channel != "/distributed_hash" }

    channels = messages.map { |m| m.channel }.sort

    # 3 for topic, one to notify of new topic, one for topic stats and another for tracking state
    expect(channels).to eq(
      [
        "/new",
        "/u/#{admin.username}",
        "/u/#{admin.username}",
        "/unread",
        "/unread/#{admin.id}",
        "/latest",
        "/latest",
        "/topic/#{created_post.topic_id}",
        "/topic/#{created_post.topic_id}",
        "/topic/#{created_post.topic_id}",
        "/user-drafts/#{admin.id}",
        "/user-drafts/#{admin.id}",
        "/user-drafts/#{admin.id}",
      ].sort,
    )

    admin_ids = [Group[:admins].id]
    expect(
      messages.any? do |m|
        m.group_ids != admin_ids && !m.user_ids.include?(other_admin.id) &&
          !m.user_ids.include?(admin.id)
      end,
    ).to eq(false)
  end

  it "generates the correct messages for a normal topic" do
    Jobs.run_immediately!
    UserActionManager.enable

    p = nil
    messages = MessageBus.track_publish { p = creator.create }

    expect(messages.find { it.channel == "/latest" }).not_to eq(nil)
    expect(messages.find { it.channel == "/new" }).not_to eq(nil)
    expect(messages.find { it.channel == "/unread/#{p.user_id}" }).not_to eq(nil)
    expect(messages.find { it.channel == "/user-drafts/#{p.user_id}" }).not_to eq(nil)

    user_action = messages.find { it.channel == "/u/#{p.user.username}" }
    expect(user_action).to eq(nil)

    topics_stats =
      messages.find { |m| m.channel == "/topic/#{p.topic.id}" && m.data[:type] == :stats }
    expect(topics_stats).to eq(nil)

    expect(messages.filter { it.channel != "/distributed_hash" }.size).to eq(6)
  end

  it "extracts links from the post" do
    create_post(raw: "this is a link to the best site at https://google.com")
    creator.create
    expect(TopicLink.count).to eq(1)
  end

  it "queues up post processing job when saved" do
    creator.create

    post = Post.last
    post_id = post.id
    topic_id = post.topic_id

    process_post_args = Jobs::ProcessPost.jobs.first["args"].first
    expect(process_post_args["post_id"]).to eq(post_id)

    feature_topic_users_args = Jobs::FeatureTopicUsers.jobs.first["args"].first
    expect(feature_topic_users_args["topic_id"]).to eq(topic_id)

    post_alert_args = Jobs::PostAlert.jobs.first["args"].first
    expect(post_alert_args["post_id"]).to eq(post_id)

    notify_mailing_list_subscribers_args =
      Jobs::NotifyMailingListSubscribers.jobs.first["args"].first

    expect(notify_mailing_list_subscribers_args["post_id"]).to eq(post_id)
  end

  it "passes the invalidate_oneboxes along to the job if present" do
    creator.opts[:invalidate_oneboxes] = true
    creator.create

    expect(job_enqueued?(job: :process_post, args: { invalidate_oneboxes: true })).to eq(true)
  end

  it "passes the image_sizes along to the job if present" do
    image_sizes = { "http://an.image.host/image.jpg" => { "width" => 17, "height" => 31 } }
    creator.opts[:image_sizes] = image_sizes
    creator.create

    expect(job_enqueued?(job: :process_post, args: { image_sizes: image_sizes })).to eq(true)
  end

  it "assigns a category when supplied" do
    expect(creator_with_category.create.topic.category).to eq(category)
  end

  it "passes the image sizes through" do
    Post.any_instance.expects(:image_sizes=).with(image_sizes)
    creator_with_image_sizes.create
  end

  it "sets topic excerpt if first post, but not second post" do
    first_post = creator.create
    topic = first_post.topic.reload
    expect(topic.excerpt).to be_present
    expect {
      PostCreator.new(
        first_post.user,
        topic_id: first_post.topic_id,
        raw: "this is the second post",
      ).create
      topic.reload
    }.to_not change { topic.excerpt }
  end

  it "supports custom excerpts" do
    raw = <<~MD
          <div class='excerpt'>
          I am

          a custom excerpt
          </div>

          testing
        MD
    post = create_post(raw: raw)

    expect(post.excerpt).to eq("I am\na custom excerpt")
  end

  it "creates post stats" do
    Draft.set(user, Draft::NEW_TOPIC, 0, "test")
    Draft.set(user, Draft::NEW_TOPIC, 0, "test1")
    expect(user.user_stat.draft_count).to eq(1)

    begin
      PostCreator.track_post_stats = true
      post = creator.create
      expect(post.post_stat.typing_duration_msecs).to eq(0)
      expect(post.post_stat.drafts_saved).to eq(2)
      expect(post.post_stat.writing_device).to eq("linux")
      expect(post.post_stat.writing_device_user_agent).to eq(
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
      )
      expect(post.post_stat.composer_version).to eq(2)
      expect(user.reload.user_stat.draft_count).to eq(0)
    ensure
      PostCreator.track_post_stats = false
    end
  end

  it "clears the draft if advanced_draft is true" do
    draft_key = Draft::NEW_TOPIC + "_#{Time.now.to_i}"
    creator = PostCreator.new(user, basic_topic_params.merge(draft_key: draft_key))
    Draft.set(user, draft_key, 0, "test")
    expect(Draft.where(user: user).size).to eq(1)
    expect { creator.create }.to change { Draft.count }.by(-1)
  end

  it "does not clear the draft if advanced_draft is false" do
    draft_key = Draft::NEW_TOPIC + "_#{Time.now.to_i}"
    creator =
      PostCreator.new(
        user,
        basic_topic_params.merge(advance_draft: false, draft_key: draft_key),
      )
    Draft.set(user, draft_key, 0, "test")
    expect(Draft.where(user: user).size).to eq(1)
    expect { creator.create }.not_to change { Draft.count }
  end

  it "updates topic stats" do
    first_post = creator.create
    topic = first_post.topic.reload

    expect(topic.last_posted_at).to eq_time(first_post.created_at)
    expect(topic.last_post_user_id).to eq(first_post.user_id)
    expect(topic.word_count).to eq(4)
  end

  it "creates a post with featured link" do
    SiteSetting.topic_featured_link_enabled = true
    SiteSetting.min_first_post_length = 100

    post = creator_with_featured_link.create
    expect(post.topic.featured_link).to eq("http://www.discourse.org")
    expect(post.valid?).to eq(true)
  end

  it "allows notification email to be skipped" do
    user_2 = Fabricate(:user)

    creator =
      PostCreator.new(
        user,
        title: "hi there welcome to my topic",
        raw: "this is my awesome message @#{user_2.username_lower}",
        archetype: Archetype.private_message,
        target_usernames: [user_2.username],
        post_alert_options: {
          skip_send_email: true,
        },
      )

    NotificationEmailer.expects(:process_notification).never

    creator.create
  end

  describe "topic's auto close" do
    it "doesn't update topic's auto close when it's not based on last post" do
      freeze_time

      topic = Fabricate(:topic).set_or_create_timer(TopicTimer.types[:close], 12)
      PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create
      topic.reload

      topic_status_update = TopicTimer.last
      expect(topic_status_update.execute_at).to eq_time(12.hours.from_now)
      expect(topic_status_update.created_at).to eq_time(Time.zone.now)
    end

    describe "topic's auto close based on last post" do
      fab!(:topic_timer) do
        Fabricate(
          :topic_timer,
          based_on_last_post: true,
          execute_at: 12.hours.ago,
          created_at: 24.hours.ago,
          duration_minutes: 12 * 60,
        )
      end

      let(:topic) { topic_timer.topic }

      fab!(:post) { Fabricate(:post, topic: topic_timer.topic) }

      it "updates topic's auto close date" do
        freeze_time
        post

        PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create

        topic_timer.reload

        expect(topic_timer.execute_at).to eq_time(12.hours.from_now)
        expect(topic_timer.created_at).to eq_time(Time.zone.now)
      end

      it "closes the topic and deletes the topic timer when the post limit is reached" do
        SiteSetting.auto_close_topics_post_count = 2
        freeze_time
        post

        PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create

        topic.reload

        expect(topic.posts.last.raw).to eq(
          I18n.t(
            "topic_statuses.autoclosed_topic_max_posts",
            count: SiteSetting.auto_close_topics_post_count,
          ),
        )

        expect(topic.closed).to eq(true)
        expect(topic_timer.reload.deleted_at).to eq_time(Time.zone.now)
      end

      it "uses the system locale for the post-limit message" do
        SiteSetting.auto_close_topics_post_count = 2
        post

        I18n.with_locale(:fr) do
          PostCreator.new(topic.user, topic_id: topic.id, raw: "this is a second post").create
        end

        topic.reload

        expect(topic.posts.last.raw).to eq(
          I18n.t(
            "topic_statuses.autoclosed_topic_max_posts",
            count: SiteSetting.auto_close_topics_post_count,
            locale: :en,
          ),
        )
      end

      it "enqueues a linked-topic job when configured after reaching the post limit" do
        SiteSetting.auto_close_topics_post_count = 2
        SiteSetting.auto_close_topics_create_linked_topic = true
        freeze_time
        post

        post_2 =
          PostCreator.new(
            topic.user,
            topic_id: topic.id,
            raw: "this is a second post",
          ).create

        topic.reload

        expect(topic.closed).to eq(true)
        expect(topic_timer.reload.deleted_at).to eq_time(Time.zone.now)
        expect(
          job_enqueued?(job: :create_linked_topic, args: { post_id: post_2.id }),
        ).to eq(true)
      end
    end
  end

  context "with tags" do
  let(:tag_names) { %w[art science dance] }
  let(:creator_with_tags) { PostCreator.new(user, basic_topic_params.merge(tags: tag_names)) }

  context "with tagging disabled" do
    before { SiteSetting.tagging_enabled = false }

    it "doesn't create tags" do
      expect { created_post = creator_with_tags.create }.not_to change { Tag.count }
      expect(created_post.topic&.tags&.size).to eq(nil)
    end
  end

  context "when the user can create tags" do
    before do
        SiteSetting.tagging_enabled = true
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      end

    it "can create all tags if none exist" do
      expect { created_post = creator_with_tags.create }.to change { Tag.count }.by(tag_names.size)
      expect(created_post.topic.tags.map(&:name).sort).to eq(tag_names.sort)
    end

    it "creates missing tags if some exist" do
      _existing_tag1 = Fabricate(:tag, name: tag_names[0])
      _existing_tag1 = Fabricate(:tag, name: tag_names[1])
      expect { created_post = creator_with_tags.create }.to change { Tag.count }.by(
        tag_names.size - 2,
      )
      expect(created_post.topic.tags.map(&:name).sort).to eq(tag_names.sort)
    end
  end

  context "when the user cannot create tags" do
    before do
        SiteSetting.tagging_enabled = true
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      end

    it "only uses existing tags" do
      existing_tag1 = Fabricate(:tag, name: tag_names[1])
      expect { created_post = creator_with_tags.create }.not_to change { Tag.count }
      expect(created_post.topic.tags.map(&:name)).to eq([existing_tag1.name])
    end
  end

  context "when automatically tagging first posts" do
    before do
        SiteSetting.tagging_enabled = true
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        Fabricate(:tag, name: "greetings")
        Fabricate(:tag, name: "hey")
        Fabricate(:tag, name: "about-art")
        Fabricate(:tag, name: "about-artists")
      end

    it "works with many plain-word tags" do
      Fabricate(
          :watched_word,
          action: WatchedWord.actions[:tag],
          word: "HELLO",
          replacement: "greetings,hey",
        )

      created_post = creator.create
      expect(created_post.topic.tags.map(&:name)).to match_array(%w[greetings hey])
    end

    it "works with overlapping plain words" do
      Fabricate(
          :watched_word,
          action: WatchedWord.actions[:tag],
          word: "art",
          replacement: "about-art",
        )
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:tag],
        word: "artist*",
        replacement: "about-artists",
      )

      post =
        PostCreator.new(
          user,
          title: "hello world topic",
          raw: "this is topic abour artists",
          archetype_id: 1,
        ).create
      expect(post.topic.tags.map(&:name)).to match_array(["about-artists"])
    end

    it "does not treat plain words as regular expressions" do
      Fabricate(
          :watched_word,
          action: WatchedWord.actions[:tag],
          word: "he(llo|y)",
          replacement: "greetings,hey",
        )

      created_post = creator_with_tags.create
      expect(created_post.topic.tags.map(&:name)).to match_array(tag_names)
    end

    it "applies tags matched by regular expressions" do
    SiteSetting.watched_words_regular_expressions = true
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "he(llo|y)",
      replacement: "greetings,hey",
    )

    created_post = creator_with_tags.create
    expect(created_post.topic.tags.map(&:name)).to match_array(tag_names + %w[greetings hey])
  end
  end
end

  context "when auto-close param is given" do
    it "ensures the user can auto-close the topic, but ignores auto-close param silently" do
      Guardian.any_instance.stubs(:can_moderate?).returns(false)
      expect {
        PostCreator.new(user, basic_topic_params.merge(auto_close_time: 2)).create!
      }.to_not change { TopicTimer.count }
    end
  end
end
end
