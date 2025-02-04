# frozen_string_literal: true

require "post_revisor"

RSpec.describe PostRevisor do
  fab!(:topic)
  fab!(:newuser) { Fabricate(:newuser, last_seen_at: Date.today) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:coding_horror)
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator)
  let(:post_args) { { user: newuser, topic: topic } }

  describe "TopicChanges" do
    let(:tc) do
      topic.reload
      PostRevisor::TopicChanges.new(topic, topic.user)
    end

    it "provides a guardian" do
      expect(tc.guardian).to be_an_instance_of Guardian
    end

    it "tracks changes properly" do
      expect(tc.diff).to eq({})

      # it remembers changes we tell it to
      tc.record_change("height", "180cm", "170cm")
      expect(tc.diff["height"]).to eq(%w[180cm 170cm])

      # it works with arrays of values
      tc.record_change("colors", nil, %w[red blue])
      expect(tc.diff["colors"]).to eq([nil, %w[red blue]])

      # it does not record changes to the same val
      tc.record_change("wat", "js", "js")
      expect(tc.diff["wat"]).to be_nil

      tc.record_change("tags", %w[a b], %w[a b])
      expect(tc.diff["tags"]).to be_nil
    end
  end

  describe "editing category" do
    it "triggers the :post_edited event with topic_changed?" do
      category = Fabricate(:category)
      category.set_permissions(everyone: :full)
      category.save!
      post = create_post
      events = DiscourseEvent.track_events { post.revise(post.user, category_id: category.id) }

      event = events.find { |e| e[:event_name] == :post_edited }

      expect(event[:params].first).to eq(post)
      expect(event[:params].second).to eq(true)
      expect(event[:params].third).to be_kind_of(PostRevisor)
      expect(event[:params].third.topic_diff).to eq(
        { "category_id" => [SiteSetting.uncategorized_category_id, category.id] },
      )
    end

    it "does not revise category when no permission to create a topic in category" do
      category = Fabricate(:category)
      category.set_permissions(staff: :full)
      category.save!

      post = create_post
      old_id = post.topic.category_id

      post.revise(post.user, category_id: category.id)

      post.reload
      expect(post.topic.category_id).to eq(old_id)

      category.set_permissions(everyone: :full)
      category.save!

      post.revise(post.user, category_id: category.id)

      post.reload
      expect(post.topic.category_id).to eq(category.id)
    end

    it "does not revise category when the destination category requires topic approval" do
      new_category = Fabricate(:category)
      new_category.require_topic_approval = true
      new_category.save!

      post = create_post
      old_category_id = post.topic.category_id

      post.revise(post.user, category_id: new_category.id)
      expect(post.reload.topic.category_id).to eq(old_category_id)

      new_category.require_topic_approval = false
      new_category.save!

      post.revise(post.user, category_id: new_category.id)
      expect(post.reload.topic.category_id).to eq(new_category.id)
    end

    it "does not revise category if incorrect amount of tags" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      new_category = Fabricate(:category, minimum_required_tags: 1)

      post = create_post
      old_category_id = post.topic.category_id

      post.revise(post.user, category_id: new_category.id)
      expect(post.reload.topic.category_id).to eq(old_category_id)

      tag = Fabricate(:tag)
      topic_tag = Fabricate(:topic_tag, topic: post.topic, tag: tag)
      post.revise(post.user, category_id: new_category.id)
      expect(post.reload.topic.category_id).to eq(new_category.id)
      topic_tag.destroy

      post.revise(post.user, category_id: new_category.id, tags: ["test_tag"])
      expect(post.reload.topic.category_id).to eq(new_category.id)
    end

    it "returns an error if the topic does not have minimum amount of tags that the new category requires" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      old_category = Fabricate(:category, minimum_required_tags: 0)
      new_category = Fabricate(:category, minimum_required_tags: 1)

      post = create_post(category: old_category)
      topic = post.topic

      post.revise(post.user, category_id: new_category.id)
      expect(topic.errors.full_messages).to eq([I18n.t("tags.minimum_required_tags", count: 1)])
    end

    it "returns an error if the topic has tags not allowed in the new category" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      tag_group = Fabricate(:tag_group, tags: [tag1])
      tag_group2 = Fabricate(:tag_group, tags: [tag2])

      old_category = Fabricate(:category, tag_groups: [tag_group])
      new_category = Fabricate(:category, tag_groups: [tag_group2])

      post = create_post(category: old_category, tags: [tag1.name])
      topic = post.topic

      post.revise(post.user, category_id: new_category.id)
      expect(topic.errors.full_messages).to eq(
        [
          I18n.t(
            "tags.forbidden.restricted_tags_cannot_be_used_in_category",
            count: 1,
            tags: tag1.name,
            category: new_category.name,
          ),
        ],
      )
    end

    it "returns an error if the topic is missing tags required from a tag group in the new category" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      tag1 = Fabricate(:tag)
      tag_group = Fabricate(:tag_group, tags: [tag1])

      old_category = Fabricate(:category)
      new_category =
        Fabricate(
          :category,
          category_required_tag_groups: [
            CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
          ],
        )

      post = create_post(category: old_category)
      topic = post.topic

      post.revise(post.user, category_id: new_category.id)
      expect(topic.errors.full_messages).to eq(
        [
          I18n.t(
            "tags.required_tags_from_group",
            count: 1,
            tag_group_name: tag_group.name,
            tags: tag1.name,
          ),
        ],
      )
    end
  end

  describe "editing tags" do
    subject(:post_revisor) { PostRevisor.new(post) }

    fab!(:post)

    before do
      Jobs.run_immediately!

      TopicUser.change(
        newuser.id,
        post.topic_id,
        notification_level: TopicUser.notification_levels[:watching],
      )
    end

    it "creates notifications" do
      expect { post_revisor.revise!(admin, tags: ["new-tag"]) }.to change { Notification.count }.by(
        1,
      )
    end

    it "skips notifications if disable_tags_edit_notifications" do
      SiteSetting.disable_tags_edit_notifications = true

      expect { post_revisor.revise!(admin, tags: ["new-tag"]) }.not_to change { Notification.count }
    end

    it "doesn't create a small_action post when create_post_for_category_and_tag_changes is false" do
      SiteSetting.create_post_for_category_and_tag_changes = false

      expect { post_revisor.revise!(admin, tags: ["new-tag"]) }.not_to change { Post.count }
    end

    describe "when `create_post_for_category_and_tag_changes` site setting is enabled" do
      fab!(:tag1) { Fabricate(:tag, name: "First tag") }
      fab!(:tag2) { Fabricate(:tag, name: "Second tag") }

      before do
        SiteSetting.create_post_for_category_and_tag_changes = true
        SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff]
      end

      it "Creates a small_action post with correct translation when both adding and removing tags" do
        post.topic.update!(tags: [tag1])

        expect { post_revisor.revise!(admin, tags: [tag2.name]) }.to change {
          Post.where(topic_id: post.topic_id, action_code: "tags_changed").count
        }.by(1)

        expect(post.topic.ordered_posts.last.raw).to eq(
          I18n.t(
            "topic_tag_changed.added_and_removed",
            added: "##{tag2.name}",
            removed: "##{tag1.name}",
          ),
        )
      end

      it "Creates a small_action post with correct translation when adding tags" do
        post.topic.update!(tags: [])

        expect { post_revisor.revise!(admin, tags: [tag1.name]) }.to change {
          Post.where(topic_id: post.topic_id, action_code: "tags_changed").count
        }.by(1)

        expect(post.topic.ordered_posts.last.raw).to eq(
          I18n.t("topic_tag_changed.added", added: "##{tag1.name}"),
        )
      end

      it "Creates a small_action post with correct translation when removing tags" do
        post.topic.update!(tags: [tag1, tag2])

        expect { post_revisor.revise!(admin, tags: []) }.to change {
          Post.where(topic_id: post.topic_id, action_code: "tags_changed").count
        }.by(1)

        expect(post.topic.ordered_posts.last.raw).to eq(
          I18n.t("topic_tag_changed.removed", removed: "##{tag1.name}, ##{tag2.name}"),
        )
      end

      it "Creates a small_action post when category is changed" do
        current_category = post.topic.category
        category = Fabricate(:category)

        expect { post_revisor.revise!(admin, category_id: category.id) }.to change {
          Post.where(topic_id: post.topic_id, action_code: "category_changed").count
        }.by(1)

        expect(post.topic.ordered_posts.last.raw).to eq(
          I18n.t(
            "topic_category_changed",
            to: "##{category.slug}",
            from: "##{current_category.slug}",
          ),
        )
      end

      it "Creates a small_action as a whisper when category is changed" do
        category = Fabricate(:category)

        expect { post_revisor.revise!(admin, category_id: category.id) }.to change {
          Post.where(topic_id: post.topic_id, action_code: "category_changed").count
        }.by(1)

        expect(post.topic.ordered_posts.last.post_type).to eq(Post.types[:whisper])
      end

      describe "with PMs" do
        fab!(:pm) { Fabricate(:private_message_topic) }
        let(:first_post) { create_post(user: admin, topic: pm, allow_uncategorized_topics: false) }
        fab!(:category) { Fabricate(:category, topic_count: 1) }
        it "Does not create a category change small_action post when converting to a topic" do
          expect do
            TopicConverter.new(first_post.topic, admin).convert_to_public_topic(category.id)
          end.to change { category.reload.topic_count }.by(1)
        end
      end
    end
  end

  describe "revise wiki" do
    before { SiteSetting.unique_posts_mins = 10 }

    it "allows the user to change it to a wiki" do
      pc =
        PostCreator.new(newuser, topic_id: topic.id, raw: "this is a post that will become a wiki")
      post = pc.create
      expect(post.revise(post.user, wiki: true)).to be_truthy
      post.reload
      expect(post.wiki).to be_truthy
    end
  end

  describe "revise" do
    subject(:post_revisor) { PostRevisor.new(post) }

    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    it "destroys last revision if edit is undone" do
      old_raw = post.raw

      post_revisor.revise!(admin, raw: "new post body", tags: ["new-tag"])
      expect(post.topic.reload.tags.map(&:name)).to contain_exactly("new-tag")
      expect(post.post_revisions.reload.size).to eq(1)
      expect(post_revisor.raw_changed?).to eq(true)

      post_revisor.revise!(admin, raw: old_raw, tags: [])
      expect(post.topic.reload.tags.map(&:name)).to be_empty
      expect(post.post_revisions.reload.size).to eq(0)

      post_revisor.revise!(admin, raw: "next post body", tags: ["new-tag"])
      expect(post.topic.reload.tags.map(&:name)).to contain_exactly("new-tag")
      expect(post.post_revisions.reload.size).to eq(1)
    end

    describe "with the same body" do
      it "doesn't change version" do
        expect {
          expect(post_revisor.revise!(post.user, raw: post.raw)).to eq(false)
          post.reload
        }.not_to change(post, :version)
      end
    end

    describe "with nil raw contents" do
      it "doesn't change version" do
        expect {
          expect(post_revisor.revise!(post.user, raw: nil)).to eq(false)
          post.reload
        }.not_to change(post, :version)
      end
    end

    describe "topic is in slow mode" do
      before { topic.update!(slow_mode_seconds: 1000) }

      it "regular edits are not allowed by default" do
        post_revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 1000.minutes,
        )

        post.reload
        expect(post.errors.present?).to eq(true)
        expect(post.errors.messages[:base].first).to be I18n.t("cannot_edit_on_slow_mode")
      end

      it "grace period editing is allowed" do
        SiteSetting.editing_grace_period = 1.minute

        post_revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.seconds,
        )

        post.reload
        expect(post.errors).to be_empty
      end

      it "regular edits are allowed if it was turned on in settings" do
        SiteSetting.slow_mode_prevents_editing = false

        post_revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.minutes,
        )

        post.reload
        expect(post.errors).to be_empty
      end

      it "staff is allowed to edit posts even if the topic is in slow mode" do
        admin = Fabricate(:admin)
        post_revisor.revise!(
          admin,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.minutes,
        )

        post.reload
        expect(post.errors).to be_empty
      end
    end

    describe "grace period editing" do
      it "correctly applies edits" do
        SiteSetting.editing_grace_period = 1.minute

        post_revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.seconds,
        )
        post.reload

        expect(post.version).to eq(1)
        expect(post.public_version).to eq(1)
        expect(post.revisions.size).to eq(0)
        expect(post.last_version_at).to eq_time(first_version_at)
        expect(post_revisor.category_changed).to be_blank
      end

      it "does create a new version if a large diff happens" do
        SiteSetting.editing_grace_period_max_diff = 10

        post = Fabricate(:post, raw: "hello world")
        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world123456789" },
          revised_at: post.updated_at + 1.second,
        )

        post.reload

        expect(post.version).to eq(1)

        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world12345678901" },
          revised_at: post.updated_at + 1.second,
        )

        post.reload
        expect(post.version).to eq(2)

        expect(post.revisions.first.modifications["raw"][0]).to eq("hello world")
        expect(post.revisions.first.modifications["cooked"][0]).to eq("<p>hello world</p>")

        SiteSetting.editing_grace_period_max_diff_high_trust = 100

        post.user.update_columns(trust_level: 2)

        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world12345678901 123456789012" },
          revised_at: post.updated_at + 1.second,
        )

        post.reload
        expect(post.version).to eq(2)
        expect(post.revisions.count).to eq(1)
      end

      it "creates a new version when the post is flagged" do
        SiteSetting.editing_grace_period = 1.minute

        post = Fabricate(:post, raw: "hello world")

        Fabricate(:flag_post_action, post: post, user: user)

        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world, JK" },
          revised_at: post.updated_at + 1.second,
        )

        post.reload
        expect(post.version).to eq(2)
        expect(post.revisions.count).to eq(1)
      end

      it "doesn't create a new version" do
        SiteSetting.editing_grace_period = 1.minute
        SiteSetting.editing_grace_period_max_diff = 100

        # making a revision
        post_revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + SiteSetting.editing_grace_period + 1.seconds,
        )
        # "roll back"
        post_revisor.revise!(
          post.user,
          { raw: "Hello world" },
          revised_at: post.updated_at + SiteSetting.editing_grace_period + 2.seconds,
        )

        post.reload

        expect(post.version).to eq(1)
        expect(post.public_version).to eq(1)
        expect(post.revisions.size).to eq(0)
      end

      it "should bump the topic" do
        expect {
          post_revisor.revise!(
            post.user,
            { raw: "updated body" },
            revised_at: post.updated_at + SiteSetting.editing_grace_period + 1.seconds,
          )
        }.to change { post.topic.bumped_at }
      end

      it "should bump topic when no topic category" do
        topic_with_no_category = Fabricate(:topic, category_id: nil)
        post_from_topic_with_no_category = Fabricate(:post, topic: topic_with_no_category)
        expect {
          result =
            post_revisor.revise!(
              Fabricate(:admin),
              raw: post_from_topic_with_no_category.raw,
              tags: ["foo"],
            )
          expect(result).to eq(true)
        }.to change { topic.reload.bumped_at }
      end

      it "should send muted and latest message" do
        TopicUser.create!(topic: post.topic, user: post.user, notification_level: 0)
        messages =
          MessageBus.track_publish("/latest") do
            post_revisor.revise!(
              post.user,
              { raw: "updated body" },
              revised_at: post.updated_at + SiteSetting.editing_grace_period + 1.seconds,
            )
          end

        muted_message = messages.find { |message| message.data["message_type"] == "muted" }
        latest_message = messages.find { |message| message.data["message_type"] == "latest" }

        expect(muted_message.data["topic_id"]).to eq(topic.id)
        expect(latest_message.data["topic_id"]).to eq(topic.id)
      end
    end

    describe "edit reasons" do
      it "does create a new version if an edit reason is provided" do
        post = Fabricate(:post, raw: "hello world")
        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world123456789", edit_reason: "this is my reason" },
          revised_at: post.updated_at + 1.second,
        )
        post.reload
        expect(post.version).to eq(2)
        expect(post.revisions.count).to eq(1)
      end

      it "resets the edit_reason attribute in post model" do
        freeze_time
        SiteSetting.editing_grace_period = 5.seconds
        post = Fabricate(:post, raw: "hello world")
        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world123456789", edit_reason: "this is my reason" },
          revised_at: post.updated_at + 1.second,
        )
        post.reload
        expect(post.edit_reason).to eq("this is my reason")

        revisor.revise!(
          post.user,
          { raw: "hello world4321" },
          revised_at: post.updated_at + 7.seconds,
        )
        post.reload
        expect(post.edit_reason).not_to be_present
      end

      it "does not create a new version if an edit reason is provided and its the same as the current edit reason" do
        post = Fabricate(:post, raw: "hello world", edit_reason: "this is my reason")
        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world123456789", edit_reason: "this is my reason" },
          revised_at: post.updated_at + 1.second,
        )
        post.reload
        expect(post.version).to eq(1)
        expect(post.revisions.count).to eq(0)
      end

      it "does not clobber the existing edit reason for a revision if it is not provided in a subsequent revision" do
        post = Fabricate(:post, raw: "hello world")
        revisor = PostRevisor.new(post)
        revisor.revise!(
          post.user,
          { raw: "hello world123456789", edit_reason: "this is my reason" },
          revised_at: post.updated_at + 1.second,
        )
        post.reload
        revisor.revise!(
          post.user,
          { raw: "hello some other thing" },
          revised_at: post.updated_at + 1.second,
        )
        expect(post.revisions.first.modifications[:edit_reason]).to eq([nil, "this is my reason"])
      end
    end

    describe "hidden post" do
      it "correctly stores the modification value" do
        post.update(hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached])
        revisor = PostRevisor.new(post)
        revisor.revise!(post.user, { raw: "hello world" }, revised_at: post.updated_at + 11.minutes)
        expect(post.revisions.first.modifications.symbolize_keys).to eq(
          cooked: ["<p>Hello world</p>", "<p>hello world</p>"],
          raw: ["Hello world", "hello world"],
        )
      end
    end

    describe "revision much later" do
      let!(:revised_at) { post.updated_at + 2.minutes }

      before do
        SiteSetting.editing_grace_period = 1.minute
        post_revisor.revise!(post.user, { raw: "updated body" }, revised_at: revised_at)
        post.reload
      end

      it "doesn't update a category" do
        expect(post_revisor.category_changed).to be_blank
      end

      it "updates the versions" do
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
      end

      it "creates a new revision" do
        expect(post.revisions.size).to eq(1)
      end

      it "updates the last_version_at" do
        expect(post.last_version_at.to_i).to eq(revised_at.to_i)
      end

      describe "new edit window" do
        before do
          post_revisor.revise!(
            post.user,
            { raw: "yet another updated body" },
            revised_at: revised_at,
          )
          post.reload
        end

        it "doesn't create a new version if you do another" do
          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
        end

        it "doesn't change last_version_at" do
          expect(post.last_version_at.to_i).to eq(revised_at.to_i)
        end

        it "doesn't update a category" do
          expect(post_revisor.category_changed).to be_blank
        end

        context "after second window" do
          let!(:new_revised_at) { revised_at + 2.minutes }

          before do
            post_revisor.revise!(
              post.user,
              { raw: "yet another, another updated body" },
              revised_at: new_revised_at,
            )
            post.reload
          end

          it "does create a new version after the edit window" do
            expect(post.version).to eq(3)
            expect(post.public_version).to eq(3)
          end

          it "does create a new version after the edit window" do
            expect(post.last_version_at.to_i).to eq(new_revised_at.to_i)
          end
        end
      end
    end

    describe "category topic" do
      let!(:category) do
        category = Fabricate(:category)
        category.update_column(:topic_id, topic.id)
        category
      end

      let(:new_description) { "this is my new description." }

      it "should have no description by default" do
        expect(category.description).to be_blank
      end

      context "with one paragraph description" do
        before do
          post_revisor.revise!(post.user, raw: new_description)
          category.reload
        end

        it "returns the changed category info" do
          expect(post_revisor.category_changed).to eq(category)
        end

        it "updates the description of the category" do
          expect(category.description).to eq(new_description)
        end
      end

      context "with multiple paragraph description" do
        before do
          post_revisor.revise!(post.user, raw: "#{new_description}\n\nOther content goes here.")
          category.reload
        end

        it "returns the changed category info" do
          expect(post_revisor.category_changed).to eq(category)
        end

        it "updates the description of the category" do
          expect(category.description).to eq(new_description)
        end
      end

      context "with invalid description without paragraphs" do
        before do
          post_revisor.revise!(post.user, raw: "# This is a title")
          category.reload
        end

        it "returns a error for the user" do
          expect(post.errors.present?).to eq(true)
          expect(post.errors.messages[:base].first).to be I18n.t(
               "category.errors.description_incomplete",
             )
        end

        it "doesn't update the description of the category" do
          expect(category.description).to eq(nil)
        end
      end

      context "when updating back to the original paragraph" do
        before do
          category.update_column(:description, "this is my description")
          post_revisor.revise!(post.user, raw: Category.post_template)
          category.reload
        end

        it "puts the description back to nothing" do
          expect(category.description).to be_blank
        end

        it "returns the changed category info" do
          expect(post_revisor.category_changed).to eq(category)
        end
      end
    end

    describe "rate limiter" do
      fab!(:changed_by) { coding_horror }

      before do
        RateLimiter.enable
        SiteSetting.editing_grace_period = 0
      end

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        post_revisor.revise!(changed_by, raw: "updated body")
      end

      it "raises error when a user gets rate limited" do
        SiteSetting.max_edits_per_day = 1
        user = Fabricate(:user, trust_level: 1)

        post_revisor.revise!(user, raw: "body (edited)")

        expect do post_revisor.revise!(user, raw: "body (edited twice) ") end.to raise_error(
          RateLimiter::LimitExceeded,
        )
      end

      it "edit limits scale up depending on user's trust level" do
        SiteSetting.max_edits_per_day = 1
        SiteSetting.tl2_additional_edits_per_day_multiplier = 2
        SiteSetting.tl3_additional_edits_per_day_multiplier = 3
        SiteSetting.tl4_additional_edits_per_day_multiplier = 4

        user = Fabricate(:user, trust_level: 2)
        expect { post_revisor.revise!(user, raw: "body (edited)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited twice)") }.to_not raise_error
        expect do post_revisor.revise!(user, raw: "body (edited three times) ") end.to raise_error(
          RateLimiter::LimitExceeded,
        )

        user = Fabricate(:user, trust_level: 3)
        expect { post_revisor.revise!(user, raw: "body (edited)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited twice)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited three times)") }.to_not raise_error
        expect do post_revisor.revise!(user, raw: "body (edited four times) ") end.to raise_error(
          RateLimiter::LimitExceeded,
        )

        user = Fabricate(:user, trust_level: 4)
        expect { post_revisor.revise!(user, raw: "body (edited)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited twice)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited three times)") }.to_not raise_error
        expect { post_revisor.revise!(user, raw: "body (edited four times)") }.to_not raise_error
        expect do post_revisor.revise!(user, raw: "body (edited five times) ") end.to raise_error(
          RateLimiter::LimitExceeded,
        )
      end
    end

    describe "admin editing a new user's post" do
      fab!(:changed_by) { Fabricate(:admin) }

      before do
        SiteSetting.newuser_max_embedded_media = 0
        url = "http://i.imgur.com/wfn7rgU.jpg"
        Oneboxer.stubs(:onebox).with(url, anything).returns("<img src='#{url}'>")
        post_revisor.revise!(changed_by, raw: "So, post them here!\n#{url}")
      end

      it "allows an admin to insert images into a new user's post" do
        expect(post.errors).to be_blank
      end

      it "marks the admin as the last updater" do
        expect(post.last_editor_id).to eq(changed_by.id)
      end
    end

    describe "new user editing their own post" do
      before do
        SiteSetting.newuser_max_embedded_media = 0
        url = "http://i.imgur.com/FGg7Vzu.gif"
        Oneboxer.stubs(:cached_onebox).with(url, anything).returns("<img src='#{url}'>")
        post_revisor.revise!(post.user, raw: "So, post them here!\n#{url}")
      end

      it "doesn't allow images to be inserted" do
        expect(post.errors).to be_present
      end
    end

    describe "with a new body" do
      before { SiteSetting.editing_grace_period_max_diff = 1000 }

      fab!(:changed_by) { coding_horror }
      let!(:result) { post_revisor.revise!(changed_by, raw: "lets update the body. Здравствуйте") }

      it "correctly updates raw" do
        expect(result).to eq(true)
        expect(post.raw).to eq("lets update the body. Здравствуйте")
        expect(post.invalidate_oneboxes).to eq(true)
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
        expect(post.revisions.size).to eq(1)
        expect(post.revisions.first.user_id).to eq(changed_by.id)

        # updates word count
        expect(post.word_count).to eq(5)
        post.topic.reload
        expect(post.topic.word_count).to eq(5)
      end

      it "increases the post_edits stat count" do
        expect do post_revisor.revise!(post.user, { raw: "This is a new revision" }) end.to change {
          post.user.user_stat.post_edits_count.to_i
        }.by(1)
      end

      context "when second poster posts again quickly" do
        it "is a grace period edit, because the second poster posted again quickly" do
          SiteSetting.editing_grace_period = 1.minute
          post_revisor.revise!(
            changed_by,
            { raw: "yet another updated body" },
            revised_at: post.updated_at + 10.seconds,
          )
          post.reload
          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
          expect(post.revisions.size).to eq(1)
        end
      end

      context "when passing skip_revision as true" do
        before do
          SiteSetting.editing_grace_period = 1.minute
          post_revisor.revise!(
            changed_by,
            { raw: "yet another updated body" },
            revised_at: post.updated_at + 10.hours,
            skip_revision: true,
          )
          post.reload
        end

        it "does not create new revision " do
          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
          expect(post.revisions.size).to eq(1)
        end
      end

      context "when editing the before_edit_post event signature" do
        it "contains post and params" do
          params = { raw: "body (edited)" }
          events = DiscourseEvent.track_events { post_revisor.revise!(user, params) }
          expect(events).to include(event_name: :before_edit_post, params: [post, params])
        end
      end
    end

    describe "topic excerpt" do
      it "topic excerpt is updated only if first post is revised" do
        revisor = PostRevisor.new(post)
        first_post = topic.first_post
        expect {
          revisor.revise!(
            first_post.user,
            { raw: "Edit the first post" },
            revised_at: first_post.updated_at + 10.seconds,
          )
          topic.reload
        }.to change { topic.excerpt }
        second_post = Fabricate(:post, post_args.merge(post_number: 2, topic_id: topic.id))
        expect {
          PostRevisor.new(second_post).revise!(second_post.user, raw: "Edit the 2nd post")
          topic.reload
        }.to_not change { topic.excerpt }
      end
    end

    it "doesn't strip starting whitespaces" do
      post_revisor.revise!(post.user, raw: "    <-- whitespaces -->    ")
      post.reload
      expect(post.raw).to eq("    <-- whitespaces -->")
    end

    it "revises and tracks changes of topic titles" do
      new_title = "New topic title"
      result =
        post_revisor.revise!(
          post.user,
          { title: new_title },
          revised_at: post.updated_at + 10.minutes,
        )

      expect(result).to eq(true)
      post.reload
      expect(post.topic.title).to eq(new_title)
      expect(post.revisions.first.modifications["title"][1]).to eq(new_title)
      expect(post_revisor.topic_title_changed?).to eq(true)
      expect(post_revisor.raw_changed?).to eq(false)
    end

    it "revises and tracks changes of topic archetypes" do
      new_archetype = Archetype.banner
      result =
        post_revisor.revise!(
          post.user,
          { archetype: new_archetype },
          revised_at: post.updated_at + 10.minutes,
        )

      expect(result).to eq(true)
      post.reload
      expect(post.topic.archetype).to eq(new_archetype)
      expect(post.revisions.first.modifications["archetype"][1]).to eq(new_archetype)
      expect(post_revisor.raw_changed?).to eq(false)
    end

    it "revises and tracks changes of topic tags" do
      post_revisor.revise!(admin, tags: ["new-tag"])
      expect(post.post_revisions.last.modifications).to eq("tags" => [[], ["new-tag"]])
      expect(post_revisor.raw_changed?).to eq(false)

      post_revisor.revise!(admin, tags: %w[new-tag new-tag-2])
      expect(post.post_revisions.last.modifications).to eq("tags" => [[], %w[new-tag new-tag-2]])
      expect(post_revisor.raw_changed?).to eq(false)

      post_revisor.revise!(admin, tags: ["new-tag-3"])
      expect(post.post_revisions.last.modifications).to eq("tags" => [[], ["new-tag-3"]])
      expect(post_revisor.raw_changed?).to eq(false)
    end

    describe "#publish_changes" do
      let!(:post) { Fabricate(:post, topic: topic) }

      it "should publish topic changes to clients" do
        revisor = PostRevisor.new(topic.ordered_posts.first, topic)

        message =
          MessageBus
            .track_publish("/topic/#{topic.id}") do
              revisor.revise!(newuser, title: "this is a test topic")
            end
            .first

        payload = message.data
        expect(payload[:reload_topic]).to eq(true)
      end
    end

    context "when logging staff edits" do
      it "doesn't log when a regular user revises a post" do
        post_revisor.revise!(post.user, raw: "lets totally update the body")
        log =
          UserHistory.where(acting_user_id: post.user.id, action: UserHistory.actions[:post_edit])
        expect(log).to be_blank
      end

      it "logs an edit when a staff member revises a post" do
        post_revisor.revise!(moderator, raw: "lets totally update the body")
        log =
          UserHistory.where(
            acting_user_id: moderator.id,
            action: UserHistory.actions[:post_edit],
          ).first
        expect(log).to be_present
        expect(log.details).to eq("Hello world\n\n---\n\nlets totally update the body")
      end

      it "doesn't log an edit when skip_staff_log is true" do
        post_revisor.revise!(
          moderator,
          { raw: "lets totally update the body" },
          skip_staff_log: true,
        )
        log =
          UserHistory.where(
            acting_user_id: moderator.id,
            action: UserHistory.actions[:post_edit],
          ).first
        expect(log).to be_blank
      end

      it "doesn't log an edit when a staff member edits their own post" do
        revisor = PostRevisor.new(Fabricate(:post, user: moderator))
        revisor.revise!(moderator, raw: "my own edit to my own thing")

        log =
          UserHistory.where(acting_user_id: moderator.id, action: UserHistory.actions[:post_edit])
        expect(log).to be_blank
      end
    end

    context "when logging group moderator edits" do
      fab!(:group_user)
      fab!(:category) { Fabricate(:category, topic: topic) }
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end

      before do
        SiteSetting.enable_category_group_moderation = true
        topic.update!(category: category)
        post.update!(topic: topic)
      end

      it "logs an edit when a group moderator revises the category description" do
        PostRevisor.new(post).revise!(
          group_user.user,
          raw: "a group moderator can update the description",
        )

        log =
          UserHistory.where(
            acting_user_id: group_user.user.id,
            action: UserHistory.actions[:post_edit],
          ).first
        expect(log).to be_present
        expect(log.details).to eq(
          "Hello world\n\n---\n\na group moderator can update the description",
        )
      end
    end

    context "with staff_edit_locks_post" do
      context "when disabled" do
        before { SiteSetting.staff_edit_locks_post = false }

        it "does not lock the post when revised" do
          result = post_revisor.revise!(moderator, raw: "lets totally update the body")
          expect(result).to eq(true)
          post.reload
          expect(post).not_to be_locked
        end
      end

      context "when enabled" do
        before { SiteSetting.staff_edit_locks_post = true }

        it "locks the post when revised by staff" do
          result = post_revisor.revise!(moderator, raw: "lets totally update the body")
          expect(result).to eq(true)
          post.reload
          expect(post).to be_locked
        end

        it "doesn't lock the wiki posts" do
          post.wiki = true
          result = post_revisor.revise!(moderator, raw: "some new raw content")
          expect(result).to eq(true)
          post.reload
          expect(post).not_to be_locked
        end

        it "doesn't lock the post when the raw did not change" do
          result = post_revisor.revise!(moderator, title: "New topic title, cool!")
          expect(result).to eq(true)
          post.reload
          expect(post.topic.title).to eq("New topic title, cool!")
          expect(post).not_to be_locked
        end

        it "doesn't lock the post when revised by a regular user" do
          result = post_revisor.revise!(user, raw: "lets totally update the body")
          expect(result).to eq(true)
          post.reload
          expect(post).not_to be_locked
        end

        it "doesn't lock the post when revised by system user" do
          result =
            post_revisor.revise!(Discourse.system_user, raw: "I usually replace hotlinked images")
          expect(result).to eq(true)
          post.reload
          expect(post).not_to be_locked
        end

        it "doesn't lock a staff member's post" do
          staff_post = Fabricate(:post, user: moderator)
          revisor = PostRevisor.new(staff_post)

          result = revisor.revise!(moderator, raw: "lets totally update the body")
          expect(result).to eq(true)
          staff_post.reload
          expect(staff_post).not_to be_locked
        end
      end
    end

    context "with alerts" do
      fab!(:mentioned_user) { Fabricate(:user) }

      before { Jobs.run_immediately! }

      it "generates a notification for a mention" do
        expect {
          post_revisor.revise!(
            user,
            raw: "Random user is mentioning @#{mentioned_user.username_lower}",
          )
        }.to change { Notification.where(notification_type: Notification.types[:mentioned]).count }
      end

      it "never generates a notification for a mention when the System user revise a post" do
        expect {
          post_revisor.revise!(
            Discourse.system_user,
            raw: "System user is mentioning @#{mentioned_user.username_lower}",
          )
        }.not_to change {
          Notification.where(notification_type: Notification.types[:mentioned]).count
        }
      end
    end

    context "with tagging" do
      context "with tagging disabled" do
        before { SiteSetting.tagging_enabled = false }

        it "doesn't add the tags" do
          result =
            post_revisor.revise!(
              user,
              raw: "lets totally update the body",
              tags: %w[totally update],
            )
          expect(result).to eq(true)
          post.reload
          expect(post.topic.tags.size).to eq(0)
        end
      end

      context "with tagging enabled" do
        before { SiteSetting.tagging_enabled = true }

        context "when can create tags" do
          before do
            SiteSetting.create_tag_allowed_groups = "1|3|#{Group::AUTO_GROUPS[:trust_level_0]}"
            SiteSetting.tag_topic_allowed_groups = "1|3|#{Group::AUTO_GROUPS[:trust_level_0]}"
          end

          it "can create all tags if none exist" do
            expect {
              @result =
                post_revisor.revise!(
                  user,
                  raw: "lets totally update the body",
                  tags: %w[totally update],
                )
            }.to change { Tag.count }.by(2)
            expect(@result).to eq(true)
            post.reload
            expect(post.topic.tags.map(&:name).sort).to eq(%w[totally update])
          end

          it "creates missing tags if some exist" do
            Fabricate(:tag, name: "totally")
            expect {
              @result =
                post_revisor.revise!(
                  user,
                  raw: "lets totally update the body",
                  tags: %w[totally update],
                )
            }.to change { Tag.count }.by(1)
            expect(@result).to eq(true)
            post.reload
            expect(post.topic.tags.map(&:name).sort).to eq(%w[totally update])
          end

          it "can remove all tags" do
            topic.tags = [Fabricate(:tag, name: "super"), Fabricate(:tag, name: "stuff")]
            result = post_revisor.revise!(user, raw: "lets totally update the body", tags: [])
            expect(result).to eq(true)
            post.reload
            expect(post.topic.tags.size).to eq(0)
          end

          it "can't add staff-only tags" do
            create_staff_only_tags(["important"])
            result =
              post_revisor.revise!(
                user,
                raw: "lets totally update the body",
                tags: %w[important stuff],
              )
            expect(result).to eq(false)
            expect(post.topic.errors.present?).to eq(true)
          end

          it "staff can add staff-only tags" do
            create_staff_only_tags(["important"])
            result =
              post_revisor.revise!(
                admin,
                raw: "lets totally update the body",
                tags: %w[important stuff],
              )
            expect(result).to eq(true)
            post.reload
            expect(post.topic.tags.map(&:name).sort).to eq(%w[important stuff])
          end

          it "triggers the :post_edited event with topic_changed?" do
            topic.tags = [Fabricate(:tag, name: "super"), Fabricate(:tag, name: "stuff")]

            events =
              DiscourseEvent.track_events do
                post_revisor.revise!(user, raw: "lets totally update the body", tags: [])
              end

            event = events.find { |e| e[:event_name] == :post_edited }

            expect(event[:params].first).to eq(post)
            expect(event[:params].second).to eq(true)
            expect(event[:params].third).to be_kind_of(PostRevisor)
            expect(event[:params].third.topic_diff).to eq({ "tags" => [%w[super stuff], []] })
          end

          context "with staff-only tags" do
            before do
              create_staff_only_tags(["important"])
              topic = post.topic
              topic.tags = [
                Fabricate(:tag, name: "super"),
                Tag.where(name: "important").first,
                Fabricate(:tag, name: "stuff"),
              ]
            end

            it "staff-only tags can't be removed" do
              result =
                post_revisor.revise!(user, raw: "lets totally update the body", tags: ["stuff"])
              expect(result).to eq(false)
              expect(post.topic.errors.present?).to eq(true)
              post.reload
              expect(post.topic.tags.map(&:name).sort).to eq(%w[important stuff super])
            end

            it "can't remove all tags if some are staff-only" do
              result = post_revisor.revise!(user, raw: "lets totally update the body", tags: [])
              expect(result).to eq(false)
              expect(post.topic.errors.present?).to eq(true)
              post.reload
              expect(post.topic.tags.map(&:name).sort).to eq(%w[important stuff super])
            end

            it "staff-only tags can be removed by staff" do
              result =
                post_revisor.revise!(admin, raw: "lets totally update the body", tags: ["stuff"])
              expect(result).to eq(true)
              post.reload
              expect(post.topic.tags.map(&:name)).to eq(["stuff"])
            end

            it "staff can remove all tags" do
              result = post_revisor.revise!(admin, raw: "lets totally update the body", tags: [])
              expect(result).to eq(true)
              post.reload
              expect(post.topic.tags.size).to eq(0)
            end
          end

          context "with hidden tags" do
            let(:bumped_at) { 1.day.ago }

            before do
              topic.update!(bumped_at: bumped_at)
              create_hidden_tags(%w[important secret])
              topic = post.topic
              topic.tags = [
                Fabricate(:tag, name: "super"),
                Tag.where(name: "important").first,
                Fabricate(:tag, name: "stuff"),
              ]
            end

            it "doesn't bump topic if only staff-only tags are added" do
              expect {
                result =
                  post_revisor.revise!(
                    Fabricate(:admin),
                    raw: post.raw,
                    tags: topic.tags.map(&:name) + ["secret"],
                  )
                expect(result).to eq(true)
              }.to_not change { topic.reload.bumped_at }
            end

            it "doesn't bump topic if only staff-only tags are removed" do
              expect {
                result =
                  post_revisor.revise!(
                    Fabricate(:admin),
                    raw: post.raw,
                    tags: topic.tags.map(&:name) - %w[important secret],
                  )
                expect(result).to eq(true)
              }.to_not change { topic.reload.bumped_at }
            end

            it "doesn't bump topic if only staff-only tags are removed and there are no tags left" do
              topic.tags = Tag.where(name: %w[important secret]).to_a
              expect {
                result = post_revisor.revise!(Fabricate(:admin), raw: post.raw, tags: [])
                expect(result).to eq(true)
              }.to_not change { topic.reload.bumped_at }
            end

            it "doesn't bump topic if empty string is given" do
              topic.tags = Tag.where(name: %w[important secret]).to_a
              expect {
                result = post_revisor.revise!(Fabricate(:admin), raw: post.raw, tags: [""])
                expect(result).to eq(true)
              }.to_not change { topic.reload.bumped_at }
            end

            it "should bump topic if non staff-only tags are added" do
              expect {
                result =
                  post_revisor.revise!(
                    Fabricate(:admin),
                    raw: post.raw,
                    tags: topic.tags.map(&:name) + [Fabricate(:tag).name],
                  )
                expect(result).to eq(true)
              }.to change { topic.reload.bumped_at }
            end

            it "creates a hidden revision" do
              post_revisor.revise!(
                Fabricate(:admin),
                raw: post.raw,
                tags: topic.tags.map(&:name) + ["secret"],
              )
              expect(post.reload.revisions.first.hidden).to eq(true)
            end

            it "doesn't notify topic owner about hidden tags" do
              PostActionNotifier.enable
              Jobs.run_immediately!
              expect {
                post_revisor.revise!(
                  Fabricate(:admin),
                  raw: post.raw,
                  tags: topic.tags.map(&:name) + ["secret"],
                )
              }.not_to change {
                Notification.where(notification_type: Notification.types[:edited]).count
              }
            end
          end

          context "with required tag group" do
            fab!(:tag1) { Fabricate(:tag) }
            fab!(:tag2) { Fabricate(:tag) }
            fab!(:tag3) { Fabricate(:tag) }
            fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }
            fab!(:category) do
              Fabricate(
                :category,
                name: "beta",
                category_required_tag_groups: [
                  CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
                ],
              )
            end

            before { post.topic.update(category: category) }

            it "doesn't allow removing all tags from the group" do
              post.topic.tags = [tag1, tag2]
              result = post_revisor.revise!(user, raw: "lets totally update the body", tags: [])
              expect(result).to eq(false)
            end

            it "allows removing some tags" do
              post.topic.tags = [tag1, tag2, tag3]
              result =
                post_revisor.revise!(user, raw: "lets totally update the body", tags: [tag1.name])
              expect(result).to eq(true)
              expect(post.reload.topic.tags.map(&:name)).to eq([tag1.name])
            end

            it "allows admins to remove the tags" do
              post.topic.tags = [tag1, tag2, tag3]
              result = post_revisor.revise!(admin, raw: "lets totally update the body", tags: [])
              expect(result).to eq(true)
              expect(post.reload.topic.tags.size).to eq(0)
            end
          end
        end

        context "when cannot create tags" do
          before do
            SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
            SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
          end

          it "only uses existing tags" do
            Fabricate(:tag, name: "totally")
            expect {
              @result =
                post_revisor.revise!(
                  user,
                  raw: "lets totally update the body",
                  tags: %w[totally update],
                )
            }.to_not change { Tag.count }
            expect(@result).to eq(true)
            post.reload
            expect(post.topic.tags.map(&:name)).to eq(["totally"])
          end
        end
      end
    end

    context "with uploads" do
      let(:image1) { Fabricate(:upload) }
      let(:image2) { Fabricate(:upload) }
      let(:image3) { Fabricate(:upload) }
      let(:image4) { Fabricate(:upload) }
      let(:post_args) { { user: user, topic: topic, raw: <<~RAW } }
        This is a post with multiple uploads
        ![image1](#{image1.short_url})
        ![image2](#{image2.short_url})
      RAW

      it "updates linked post uploads" do
        post.link_post_uploads
        expect(post.upload_references.pluck(:upload_id)).to contain_exactly(image1.id, image2.id)

        post_revisor.revise!(user, raw: <<~RAW)
          This is a post with multiple uploads
          ![image2](#{image2.short_url})
          ![image3](#{image3.short_url})
          ![image4](#{image4.short_url})
        RAW

        expect(post.reload.upload_references.pluck(:upload_id)).to contain_exactly(
          image2.id,
          image3.id,
          image4.id,
        )
      end

      context "with secure uploads uploads" do
        let!(:image5) { Fabricate(:secure_upload) }
        before do
          Jobs.run_immediately!
          setup_s3
          SiteSetting.authorized_extensions = "png|jpg|gif|mp4"
          SiteSetting.secure_uploads = true
          stub_upload(image5)
        end

        it "updates the upload secure status, which is secure by default from the composer. set to false for a public topic" do
          stub_image_size
          post_revisor.revise!(user, raw: <<~RAW)
            This is a post with a secure upload
            ![image5](#{image5.short_url})
          RAW

          expect(image5.reload.secure).to eq(false)
          expect(image5.security_last_changed_reason).to eq(
            "access control post dictates security | source: post processor",
          )
        end

        it "does not update the upload secure status, which is secure by default from the composer for a private" do
          post.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
          stub_image_size
          post_revisor.revise!(user, raw: <<~RAW)
            This is a post with a secure upload
            ![image5](#{image5.short_url})
          RAW

          expect(image5.reload.secure).to eq(true)
          expect(image5.security_last_changed_reason).to eq(
            "access control post dictates security | source: post processor",
          )
        end
      end
    end

    context "with drafts" do
      it "does not advance draft sequence if keep_existing_draft option is true" do
        post = Fabricate(:post, user: user)
        topic = post.topic
        draft_key = "topic_#{topic.id}"
        data = { reply: "test 12222" }.to_json
        Draft.set(user, draft_key, 0, data)
        Draft.set(user, draft_key, 0, data)
        expect {
          PostRevisor.new(post).revise!(
            post.user,
            { title: "updated title for my topic" },
            keep_existing_draft: true,
          )
        }.to not_change {
          Draft.where(user: user, draft_key: draft_key).first.sequence
        }.and not_change {
                DraftSequence.where(user_id: user.id, draft_key: draft_key).first.sequence
              }

        expect {
          PostRevisor.new(post).revise!(post.user, { title: "updated title for my topic" })
        }.to change { Draft.where(user: user, draft_key: draft_key).count }.from(1).to(
          0,
        ).and change {
                DraftSequence.where(user_id: user.id, draft_key: draft_key).first.sequence
              }.by(1)
      end
    end

    context "when skipping validations" do
      fab!(:post) { Fabricate(:post, raw: "aaa", skip_validation: true) }

      it "can revise multiple times and remove unnecessary revisions" do
        post_revisor.revise!(admin, { raw: "bbb" }, skip_validations: true)
        expect(post.errors).to be_empty

        # Revert to old version which was invalid to destroy previously created
        # post revision and trigger another post save.
        post_revisor.revise!(admin, { raw: "aaa" }, skip_validations: true)
        expect(post.errors).to be_empty
      end
    end
  end

  context "when the review_every_post setting is enabled" do
    let(:post) { Fabricate(:post, post_args) }
    let(:revisor) { PostRevisor.new(post) }

    before { SiteSetting.review_every_post = true }

    it "queues the post when a regular user edits it" do
      expect {
        revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.minutes,
        )
      }.to change(ReviewablePost, :count).by(1)
    end

    it "does nothing when a staff member edits a post" do
      admin = Fabricate(:admin)

      expect { revisor.revise!(admin, { raw: "updated body" }) }.not_to change(
        ReviewablePost,
        :count,
      )
    end

    it "skips grace period edits" do
      SiteSetting.editing_grace_period = 1.minute

      expect {
        revisor.revise!(
          post.user,
          { raw: "updated body" },
          revised_at: post.updated_at + 10.seconds,
        )
      }.not_to change(ReviewablePost, :count)
    end
  end
end
