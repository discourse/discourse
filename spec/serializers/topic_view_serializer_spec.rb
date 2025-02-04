# frozen_string_literal: true

RSpec.describe TopicViewSerializer do
  def serialize_topic(topic, user_arg, opts = {})
    topic_view = TopicView.new(topic.id, user_arg, opts)

    serializer =
      TopicViewSerializer.new(topic_view, scope: Guardian.new(user_arg), root: false).as_json

    JSON.parse(MultiJson.dump(serializer)).deep_symbolize_keys!
  end

  fab!(:topic)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:admin)

  describe "#featured_link and #featured_link_root_domain" do
    fab!(:featured_link) { "http://meta.discourse.org" }

    describe "when topic featured link is disable" do
      it "should return the right attributes" do
        topic.update!(featured_link: featured_link)
        SiteSetting.topic_featured_link_enabled = false

        json = serialize_topic(topic, user)

        expect(json[:featured_link]).to eq(nil)
        expect(json[:featured_link_root_domain]).to eq(nil)
      end
    end

    describe "when topic featured link is enabled" do
      it "should return the right attributes" do
        topic.update!(featured_link: featured_link)

        json = serialize_topic(topic, user)

        expect(json[:featured_link]).to eq(featured_link)
        expect(json[:featured_link_root_domain]).to eq("discourse.org")
      end
    end
  end

  describe "#external_id" do
    describe "when a topic has an external_id" do
      before { topic.update!(external_id: "42-asdf") }

      it "should return the external_id" do
        json = serialize_topic(topic, user)
        expect(json[:external_id]).to eq("42-asdf")
      end
    end
  end

  describe "#image_url" do
    fab!(:image_upload) { Fabricate(:image_upload, width: 5000, height: 5000) }

    describe "when a topic has an image" do
      before { topic.update!(image_upload_id: image_upload.id) }

      it "should return the image url" do
        json = serialize_topic(topic, user)

        expect(json[:image_url]).to end_with(image_upload.url)
      end

      it "should have thumbnail jobs enqueued" do
        SiteSetting.create_thumbnails = true

        Discourse.redis.del(topic.thumbnail_job_redis_key([]))
        json = nil

        expect do json = serialize_topic(topic, user) end.to change {
          Jobs::GenerateTopicThumbnails.jobs.size
        }.by(1)

        topic.generate_thumbnails!

        expect do json = serialize_topic(topic, user) end.not_to change {
          Jobs::GenerateTopicThumbnails.jobs.size
        }
      end
    end

    describe "when a topic does not contain an image" do
      it "should return a nil image url" do
        json = serialize_topic(topic, user)

        expect(json.has_key? :image_url).to eq(true)
        expect(json[:image_url]).to eq(nil)
      end
    end
  end

  describe "#suggested_topics" do
    fab!(:topic2) { Fabricate(:topic) }

    before { TopicUser.update_last_read(user, topic2.id, 0, 0, 0) }

    it "should include suggested topics if `TopicView#include_suggested` is set to `true`" do
      json = serialize_topic(topic, user, include_suggested: true)

      expect(json[:suggested_topics].first[:id]).to eq(topic2.id)
    end

    it "should not include suggested topics if `TopicView#include_suggested` is set to `false`" do
      post = Fabricate(:post, topic:)
      post2 = Fabricate(:post, topic:)

      json = serialize_topic(topic, user, include_suggested: false)

      expect(json[:suggested_topics]).to eq(nil)
    end

    describe "with private messages" do
      fab!(:topic) do
        Fabricate(
          :private_message_topic,
          highest_post_number: 1,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
        )
      end

      fab!(:topic2) do
        Fabricate(
          :private_message_topic,
          highest_post_number: 1,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
        )
      end

      it "includes suggested topics" do
        TopicUser.change(
          user,
          topic2.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        json = serialize_topic(topic, user)
        expect(json[:suggested_topics].map { |t| t[:id] }).to contain_exactly(topic2.id)
      end

      it "does not include suggested topics if all PMs are read" do
        TopicUser.update_last_read(user, topic2.id, 1, 1, 0)

        json = serialize_topic(topic, user)
        expect(json[:suggested_topics]).to eq([])
      end
    end
  end

  describe "#suggested_group_name" do
    fab!(:pm) { Fabricate(:private_message_post).topic }
    fab!(:group)

    it "is nil for a regular topic" do
      json = serialize_topic(topic, user)

      expect(json[:suggested_group_name]).to eq(nil)
    end

    it "is nil if user is an allowed user of the private message" do
      pm.allowed_users << user

      json = serialize_topic(pm, user)

      expect(json[:suggested_group_name]).to eq(nil)
    end

    it "returns the right group name if user is part of allowed group in the private message" do
      pm.allowed_groups << group
      group.add(user)

      json = serialize_topic(pm, user)

      expect(json[:suggested_group_name]).to eq(group.name)
    end
  end

  describe "when tags added to private message topics" do
    fab!(:moderator)
    fab!(:tag)
    fab!(:pm) do
      Fabricate(
        :private_message_topic,
        tags: [tag],
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: moderator),
          Fabricate.build(:topic_allowed_user, user: user),
        ],
      )
    end

    fab!(:group)
    fab!(:pm_between_reg_users) do
      Fabricate(
        :private_message_topic,
        tags: [tag],
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user),
          Fabricate.build(:topic_allowed_user, user: user_2),
        ],
      )
    end

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.pm_tags_allowed_for_groups = "1|2|3|4"
    end

    it "should not include the tag for normal users" do
      json = serialize_topic(pm, user)
      expect(json[:tags]).to eq(nil)
    end

    it "should include the tag for staff users" do
      [moderator, admin].each do |user|
        json = serialize_topic(pm, user)
        expect(json[:tags]).to eq([tag.name])
      end
    end

    it "should include the tag for users in allowed groups" do
      SiteSetting.pm_tags_allowed_for_groups = "1|2|3|#{group.id}"

      user.group_users << Fabricate(:group_user, group: group, user: user)
      json = serialize_topic(pm_between_reg_users, user)
      expect(json[:tags]).to eq([tag.name])

      json = serialize_topic(pm_between_reg_users, user_2)
      expect(json[:tags]).to eq(nil)
    end

    it "should not include the tag if pm tags disabled" do
      SiteSetting.pm_tags_allowed_for_groups = ""

      [moderator, admin].each do |user|
        json = serialize_topic(pm, user)
        expect(json[:tags]).to eq(nil)
      end
    end
  end

  describe "with hidden tags" do
    fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }
    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    before { topic.tags << hidden_tag }

    it "returns hidden tag to staff" do
      json = serialize_topic(topic, admin)
      expect(json[:tags]).to eq([hidden_tag.name])
    end

    it "does not return hidden tag to non-staff" do
      json = serialize_topic(topic, user)
      expect(json[:tags]).to eq([])
    end
  end

  describe "tags order" do
    fab!(:tag1) do
      Fabricate(
        :tag,
        name: "ctag",
        description: "c description",
        staff_topic_count: 5,
        public_topic_count: 5,
      )
    end
    fab!(:tag2) do
      Fabricate(
        :tag,
        name: "btag",
        description: "b description",
        staff_topic_count: 9,
        public_topic_count: 9,
      )
    end
    fab!(:tag3) do
      Fabricate(
        :tag,
        name: "atag",
        description: "a description",
        staff_topic_count: 3,
        public_topic_count: 3,
      )
    end

    before do
      topic.tags << tag1
      topic.tags << tag2
      topic.tags << tag3
    end

    it "tags are automatically sorted by tag popularity" do
      json = serialize_topic(topic, user)
      expect(json[:tags]).to eq(%w[btag ctag atag])
      expect(json[:tags_descriptions]).to eq(
        { btag: "b description", ctag: "c description", atag: "a description" },
      )
    end

    it "tags can be sorted alphabetically" do
      SiteSetting.tags_sort_alphabetically = true
      json = serialize_topic(topic, user)
      expect(json[:tags]).to eq(%w[atag btag ctag])
    end
  end

  context "with flags" do
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:other_post) { Fabricate(:post, topic: topic) }
    fab!(:flagger_1) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:flagger_2) { Fabricate(:user, refresh_auto_groups: true) }

    it "will return reviewable counts on posts" do
      r = PostActionCreator.inappropriate(flagger_1, post).reviewable
      r.perform(admin, :agree_and_keep)
      PostActionCreator.spam(flagger_2, post)

      json = serialize_topic(topic, admin)
      p0 = json[:post_stream][:posts][0]
      expect(p0[:id]).to eq(post.id)
      expect(p0[:reviewable_score_count]).to eq(2)
      expect(p0[:reviewable_score_pending_count]).to eq(1)

      p1 = json[:post_stream][:posts][1]
      expect(p1[:reviewable_score_count]).to eq(0)
      expect(p1[:reviewable_score_pending_count]).to eq(0)
    end
  end

  describe "pending posts" do
    context "when the queue is enabled" do
      before { SiteSetting.approve_post_count = 1 }

      fab!(:queued_post) do
        ReviewableQueuedPost.needs_review!(
          topic: topic,
          payload: {
            raw: "hello my raw contents",
          },
          created_by: Discourse.system_user,
          target_created_by: user,
        )
      end

      it "returns a pending_posts_count when the queue is enabled" do
        json = serialize_topic(topic, admin)
        expect(json[:queued_posts_count]).to eq(1)
      end

      it "returns a user's pending posts" do
        json = serialize_topic(topic, user)
        expect(json[:queued_posts_count]).to be_nil

        post = json[:pending_posts].find { |p| p[:id] = queued_post.id }
        expect(post[:raw]).to eq("hello my raw contents")
        expect(post).to be_present
      end
    end
  end

  context "without an enabled queue" do
    it "returns nil for the count" do
      json = serialize_topic(topic, admin)
      expect(json[:queued_posts_count]).to be_nil
      expect(json[:pending_posts]).to be_nil
    end
  end

  context "with details" do
    it "returns the details object" do
      PostCreator.create!(user, topic_id: topic.id, raw: "this is my post content")
      topic.topic_links.create!(
        user: user,
        url: "https://discourse.org",
        domain: "discourse.org",
        clicks: 100,
      )
      json = serialize_topic(topic, admin)

      details = json[:details]
      expect(details).to be_present
      expect(details[:created_by][:id]).to eq(topic.user_id)
      expect(details[:last_poster][:id]).to eq(user.id)
      expect(details[:notification_level]).to be_present
      expect(details[:can_move_posts]).to eq(true)
      expect(details[:can_flag_topic]).to eq(true)
      expect(details[:can_review_topic]).to eq(true)
      expect(details[:links][0][:clicks]).to eq(100)

      participant = details[:participants].find { |p| p[:id] == user.id }
      expect(participant[:post_count]).to eq(1)
    end

    it "returns extra fields for a personal message" do
      group = Fabricate(:group)
      GroupUser.create(group: group, user: user)
      GroupUser.create(group: group, user: admin)

      group2 = Fabricate(:group)
      GroupUser.create(group: group2, user: user)

      pm = Fabricate(:private_message_topic)
      pm.update(archetype: "private_message")
      pm.topic_allowed_groups.create!(group: group)
      pm.topic_allowed_groups.create!(group: group2)

      json = serialize_topic(pm, admin)

      details = json[:details]
      expect(details[:can_remove_self_id]).to eq(admin.id)
      expect(details[:allowed_users].find { |au| au[:id] == pm.user_id }).to be_present
      expect(details[:allowed_groups].find { |ag| ag[:id] == group.id }).to be_present
    end

    it "has can_publish_page if possible" do
      SiteSetting.enable_page_publishing = true

      json = serialize_topic(topic, user)
      expect(json[:details][:can_publish_page]).to be_blank

      json = serialize_topic(topic, admin)
      expect(json[:details][:can_publish_page]).to eq(true)
    end

    context "with can_edit_tags" do
      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      end

      it "returns true when user can edit a wiki topic" do
        post = Fabricate(:post, wiki: true)
        topic = Fabricate(:topic, first_post: post)

        json = serialize_topic(topic, user)
        expect(json[:details][:can_edit_tags]).to be_nil

        user.change_trust_level!(TrustLevel[2])

        json = serialize_topic(topic, user.reload)
        expect(json[:details][:can_edit_tags]).to eq(true)
      end
    end

    context "with can_edit" do
      fab!(:group_user)
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      let(:user) { group_user.user }

      before { SiteSetting.enable_category_group_moderation = true }

      it "explicitly returns can_edit" do
        json = serialize_topic(topic, user)
        expect(json[:details][:can_edit]).to eq(true)

        topic.update!(category: nil)

        json = serialize_topic(topic, user)
        expect(json[:details][:can_edit]).to eq(false)
      end
    end
  end

  context "with published_page" do
    fab!(:published_page) { Fabricate(:published_page, topic: topic) }

    context "when page publishing is disabled" do
      before { SiteSetting.enable_page_publishing = false }

      it "doesn't return the published page if not enabled" do
        json = serialize_topic(topic, admin)
        expect(json[:published_page]).to be_blank
      end
    end

    context "when page publishing is enabled" do
      before { SiteSetting.enable_page_publishing = true }

      context "when not staff" do
        it "doesn't return the published page" do
          json = serialize_topic(topic, user)
          expect(json[:published_page]).to be_blank
        end
      end

      context "when staff" do
        it "returns the published page" do
          json = serialize_topic(topic, admin)
          expect(json[:published_page]).to be_present
          expect(json[:published_page][:slug]).to eq(published_page.slug)
        end

        context "when secure uploads is enabled" do
          before do
            setup_s3
            SiteSetting.secure_uploads = true
          end

          it "doesn't return the published page" do
            json = serialize_topic(topic, admin)
            expect(json[:published_page]).to be_blank
          end
        end
      end
    end
  end

  context "when viewing private messages when enable_category_group_moderation is enabled" do
    fab!(:pm_topic) do
      Fabricate(
        :private_message_topic,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user),
          Fabricate.build(:topic_allowed_user, user: admin),
        ],
      )
    end
    fab!(:post) { Fabricate(:post, topic: pm_topic) }

    before { SiteSetting.enable_category_group_moderation = true }

    # Ensure having enable_category_group_moderation turned on doesn't break private messages
    it "should return posts" do
      json = serialize_topic(pm_topic, user)
      expect(json[:post_stream][:posts]).to be_present
    end
  end

  describe "#user_last_posted_at" do
    context "when the slow mode is disabled" do
      it "returns nil" do
        Fabricate(:topic_user, user: user, topic: topic, last_posted_at: 6.hours.ago)

        json = serialize_topic(topic, user)

        expect(json[:user_last_posted_at]).to be_nil
      end
    end

    context "when the slow mode is enabled" do
      before { topic.update!(slow_mode_seconds: 1000) }

      it "returns nil if no user is given" do
        json = serialize_topic(topic, nil)

        expect(json[:user_last_posted_at]).to be_nil
      end

      it "returns nil if there's no topic_user association" do
        json = serialize_topic(topic, user)

        expect(json[:user_last_posted_at]).to be_nil
      end

      it "returns the last time the user posted" do
        Fabricate(:topic_user, user: user, topic: topic, last_posted_at: 6.hours.ago)
        json = serialize_topic(topic, user)

        expect(json[:user_last_posted_at]).to be_present
      end
    end
  end

  describe "#requested_group_name" do
    fab!(:pm) { Fabricate(:private_message_post).topic }
    fab!(:group)

    it "should return the right group name when PM is a group membership request" do
      pm.custom_fields[:requested_group_id] = group.id
      pm.save!

      user = pm.first_post.user
      group.add_owner(user)
      json = serialize_topic(pm, user)

      expect(json[:requested_group_name]).to eq(group.name)
    end

    it "should not include the attribute for a non group membership request PM" do
      json = serialize_topic(pm, pm.first_post.user)

      expect(json[:requested_group_name]).to eq(nil)
    end
  end

  describe "#topic_timer" do
    it "does not include the attribute when topic does not have a topic timer" do
      json = serialize_topic(topic, user)

      expect(json[:topic_timer]).to eq(nil)
    end

    it "includes the attribute when topic has a public topic timer" do
      topic_timer =
        Fabricate(:topic_timer, topic: topic, execute_at: Time.utc(2022, 4, 6, 16, 23, 56))
      json = serialize_topic(topic, user)

      expect(json[:topic_timer][:id]).to eq(topic_timer.id)
      expect(json[:topic_timer][:based_on_last_post]).to eq(false)
      expect(json[:topic_timer][:category_id]).to eq(nil)
      expect(json[:topic_timer][:duration_minutes]).to eq(nil)
      expect(json[:topic_timer][:execute_at]).to eq("2022-04-06T16:23:56.000Z")
      expect(json[:topic_timer][:status_type]).to eq("close")
    end

    it "does not include the attribute for category topic timer where category is restricted to user" do
      category = Fabricate(:category, read_restricted: true)

      Fabricate(
        :topic_timer,
        topic: topic,
        category_id: category.id,
        status_type: TopicTimer.types[:publish_to_category],
      )

      json = serialize_topic(topic, user)

      expect(json[:topic_timer]).to eq(nil)
    end

    it "includes the attribute  for category topic timer where category is not restricted to user" do
      category = Fabricate(:category, read_restricted: false)

      topic_timer =
        Fabricate(
          :topic_timer,
          topic: topic,
          category_id: category.id,
          status_type: TopicTimer.types[:publish_to_category],
        )

      json = serialize_topic(topic, user)

      expect(json[:topic_timer][:id]).to eq(topic_timer.id)
    end
  end
end
