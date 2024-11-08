# frozen_string_literal: true

RSpec.describe ReviewableQueuedPost, type: :model do
  fab!(:category)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }

  describe "creating a post" do
    let!(:topic) { Fabricate(:topic, category: category) }
    let(:reviewable) { Fabricate(:reviewable_queued_post, topic: topic) }

    context "when creating" do
      it "triggers queued_post_created" do
        event = DiscourseEvent.track(:queued_post_created) { reviewable.save! }
        expect(event).to be_present
        expect(event[:params][0]).to eq(reviewable)
      end

      it "returns the appropriate create options" do
        create_options = reviewable.create_options

        expect(create_options[:topic_id]).to eq(topic.id)
        expect(create_options[:raw]).to eq("hello world post contents.")
        expect(create_options[:reply_to_post_number]).to eq(1)
        expect(create_options[:via_email]).to eq(true)
        expect(create_options[:raw_email]).to eq("store_me")
        expect(create_options[:auto_track]).to eq(true)
        expect(create_options[:custom_fields]).to eq("hello" => "world")
        expect(create_options[:cooking_options]).to eq(cat: "hat")
        expect(create_options[:cook_method]).to eq(Post.cook_methods[:raw_html])
        expect(create_options[:not_create_option]).to eq(nil)
        expect(create_options[:image_sizes]).to eq(
          "http://foo.bar/image.png" => {
            "width" => 0,
            "height" => 222,
          },
        )
      end
    end

    describe "actions" do
      context "with approve_post" do
        it "triggers an extensibility event" do
          event =
            DiscourseEvent.track(:approved_post) { reviewable.perform(moderator, :approve_post) }
          expect(event).to be_present
          expect(event[:params].first).to eq(reviewable)
        end

        it "creates a post" do
          topic_count, post_count = Topic.count, Post.count
          result = nil

          Jobs.run_immediately!
          event =
            DiscourseEvent.track(:before_create_notifications_for_users) do
              result = reviewable.perform(moderator, :approve_post)
            end

          expect(result.success?).to eq(true)
          expect(result.created_post).to be_present
          expect(event).to be_present
          expect(result.created_post).to be_valid
          expect(result.created_post.topic).to eq(topic)
          expect(result.created_post.custom_fields["hello"]).to eq("world")
          expect(result.created_post_topic).to eq(topic)
          expect(result.created_post.user).to eq(reviewable.target_created_by)
          expect(reviewable.target_id).to eq(result.created_post.id)

          expect(Topic.count).to eq(topic_count)
          expect(Post.count).to eq(post_count + 1)

          notifications =
            Notification.where(
              user: reviewable.target_created_by,
              notification_type: Notification.types[:post_approved],
            )
          expect(notifications).to be_present

          # We can't approve twice
          expect { reviewable.perform(moderator, :approve_post) }.to raise_error(
            Reviewable::InvalidAction,
          )
        end

        it "skips validations" do
          reviewable.payload["raw"] = "x"
          result = reviewable.perform(moderator, :approve_post)
          expect(result.created_post).to be_present
        end

        it "Allows autosilenced users to post" do
          newuser = reviewable.created_by
          newuser.update!(trust_level: 0)
          post = Fabricate(:post, user: newuser)
          PostActionCreator.spam(moderator, post)
          Reviewable.set_priorities(high: 1.0)
          SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivities[:low]
          SiteSetting.num_users_to_silence_new_user = 1
          expect(Guardian.new(newuser).can_create_post?(topic)).to eq(false)

          result = reviewable.perform(moderator, :approve_post)
          expect(result.success?).to eq(true)
        end
      end

      context "with reject_post" do
        it "triggers an extensibility event" do
          event =
            DiscourseEvent.track(:rejected_post) { reviewable.perform(moderator, :reject_post) }
          expect(event).to be_present
          expect(event[:params].first).to eq(reviewable)
        end

        it "doesn't create a post" do
          post_count = Post.count
          result = reviewable.perform(moderator, :reject_post)
          expect(result.success?).to eq(true)
          expect(result.created_post).to be_nil
          expect(Post.count).to eq(post_count)

          # We can't reject twice
          expect { reviewable.perform(moderator, :reject_post) }.to raise_error(
            Reviewable::InvalidAction,
          )
        end
      end

      context "with revise_and_reject_post" do
        fab!(:contact_group) { Fabricate(:group) }
        fab!(:contact_user) { Fabricate(:user) }

        before do
          SiteSetting.site_contact_group_name = contact_group.name
          SiteSetting.site_contact_username = contact_user.username
        end

        it "doesn't create the post the user intended" do
          post_count = Post.public_posts.count
          result = reviewable.perform(moderator, :revise_and_reject_post)
          expect(result.success?).to eq(true)
          expect(result.created_post).to be_nil
          expect(Post.public_posts.count).to eq(post_count)
        end

        it "creates a private message to the creator of the post" do
          args = { revise_reason: "Duplicate", revise_feedback: "This is old news" }
          expect { reviewable.perform(moderator, :revise_and_reject_post, args) }.to change {
            Topic.where(archetype: Archetype.private_message).count
          }

          topic = Topic.where(archetype: Archetype.private_message).last
          expect(topic.title).to eq(
            I18n.t(
              "system_messages.reviewable_queued_post_revise_and_reject.subject_template",
              topic_title: reviewable.topic.title,
            ),
          )
          translation_params = {
            username: reviewable.target_created_by.username,
            topic_title: reviewable.topic.title,
            topic_url: reviewable.topic.url,
            reason: args[:revise_reason],
            feedback: args[:revise_feedback],
            original_post: reviewable.payload["raw"],
            site_name: SiteSetting.title,
          }
          expect(topic.topic_allowed_users.pluck(:user_id)).to include(contact_user.id)
          expect(topic.topic_allowed_groups.pluck(:group_id)).to include(contact_group.id)
          expect(topic.first_post.raw.chomp).to eq(
            I18n.t(
              "system_messages.reviewable_queued_post_revise_and_reject.text_body_template",
              translation_params,
            ).chomp,
          )
        end

        it "supports sending a custom revise reason" do
          args = {
            revise_reason: "Other...",
            revise_feedback: "This is old news",
            revise_custom_reason: "Boring",
          }
          expect { reviewable.perform(moderator, :revise_and_reject_post, args) }.to change {
            Topic.where(archetype: Archetype.private_message).count
          }
          topic = Topic.where(archetype: Archetype.private_message).last

          expect(topic.topic_allowed_users.pluck(:user_id)).to include(contact_user.id)
          expect(topic.topic_allowed_groups.pluck(:group_id)).to include(contact_group.id)
          expect(topic.first_post.raw).not_to include("Other...")
          expect(topic.first_post.raw).to include("Boring")
        end

        context "when the topic is nil in the case of a new topic being created" do
          let(:reviewable) { Fabricate(:reviewable_queued_post_topic) }

          it "works" do
            args = { revise_reason: "Duplicate", revise_feedback: "This is old news" }
            expect { reviewable.perform(moderator, :revise_and_reject_post, args) }.to change {
              Topic.where(archetype: Archetype.private_message).count
            }
            topic = Topic.where(archetype: Archetype.private_message).last

            expect(topic.title).to eq(
              I18n.t(
                "system_messages.reviewable_queued_post_revise_and_reject_new_topic.subject_template",
                topic_title: reviewable.payload["title"],
              ),
            )
            translation_params = {
              username: reviewable.target_created_by.username,
              topic_title: reviewable.payload["title"],
              topic_url: nil,
              reason: args[:revise_reason],
              feedback: args[:revise_feedback],
              original_post: reviewable.payload["raw"],
              site_name: SiteSetting.title,
            }
            expect(topic.first_post.raw.chomp).to eq(
              I18n.t(
                "system_messages.reviewable_queued_post_revise_and_reject_new_topic.text_body_template",
                translation_params,
              ).chomp,
            )
          end
        end
      end

      context "with delete_user" do
        it "deletes the user and rejects the post" do
          other_reviewable =
            Fabricate(:reviewable_queued_post, created_by: reviewable.target_created_by)

          result = reviewable.perform(moderator, :delete_user)
          expect(result.success?).to eq(true)
          expect(User.find_by(id: reviewable.target_created_by)).to be_blank

          expect(result.remove_reviewable_ids).to include(reviewable.id)
          expect(result.remove_reviewable_ids).to include(other_reviewable.id)

          expect(ReviewableQueuedPost.where(id: reviewable.id)).to be_present
          expect(ReviewableQueuedPost.where(id: other_reviewable.id)).to be_blank
        end
      end
    end
  end

  describe "creating a topic" do
    let(:reviewable) { Fabricate(:reviewable_queued_post_topic, category: category) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    end

    context "when editing" do
      it "is editable and returns the fields" do
        fields = reviewable.editable_for(Guardian.new(moderator))
        expect(fields.has?("category_id")).to eq(true)
        expect(fields.has?("payload.raw")).to eq(true)
        expect(fields.has?("payload.title")).to eq(true)
        expect(fields.has?("payload.tags")).to eq(true)
      end

      it "is editable by a category group reviewer" do
        fields = reviewable.editable_for(Guardian.new(Fabricate(:user)))
        expect(fields.has?("category_id")).to eq(false)
        expect(fields.has?("payload.raw")).to eq(true)
        expect(fields.has?("payload.title")).to eq(true)
        expect(fields.has?("payload.tags")).to eq(true)
      end
    end

    it "returns the appropriate create options for a topic" do
      create_options = reviewable.create_options
      expect(create_options[:category]).to eq(reviewable.category.id)
      expect(create_options[:archetype]).to eq("regular")
    end

    it "creates the post and topic when approved" do
      topic_count, post_count = Topic.count, Post.count
      result = reviewable.perform(moderator, :approve_post)

      expect(result.success?).to eq(true)
      expect(result.created_post).to be_present
      expect(result.created_post).to be_valid
      expect(result.created_post_topic).to be_present
      expect(result.created_post_topic).to be_valid
      expect(reviewable.target_id).to eq(result.created_post.id)
      expect(reviewable.topic_id).to eq(result.created_post_topic.id)

      expect(Topic.count).to eq(topic_count + 1)
      expect(Post.count).to eq(post_count + 1)
    end

    it "creates a topic with staff tag when approved" do
      hidden_tag = Fabricate(:tag)
      staff_tag_group =
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      reviewable.payload["tags"] += [hidden_tag.name]

      result = reviewable.perform(moderator, :approve_post)

      expect(result.success?).to eq(true)
      expect(result.created_post_topic).to be_present
      expect(result.created_post_topic).to be_valid
      expect(reviewable.topic_id).to eq(result.created_post_topic.id)
      expect(result.created_post_topic.tags.pluck(:name)).to match_array(reviewable.payload["tags"])
    end

    it "does not create the post and topic when rejected" do
      topic_count, post_count = Topic.count, Post.count
      result = reviewable.perform(moderator, :reject_post)

      expect(result.success?).to eq(true)
      expect(result.created_post).to be_blank
      expect(result.created_post_topic).to be_blank

      expect(Topic.count).to eq(topic_count)
      expect(Post.count).to eq(post_count)
    end
  end

  describe "Callbacks" do
    context "when creating a new pending reviewable" do
      let(:reviewable) do
        Fabricate.build(
          :reviewable_queued_post_topic,
          category: category,
          created_by: moderator,
          target_created_by: user,
        )
      end
      let(:user) { Fabricate(:user) }
      let(:user_stats) { user.user_stat }

      it "updates user stats" do
        user_stats.expects(:update_pending_posts)
        reviewable.save!
      end
    end

    context "when updating an existing reviewable" do
      let!(:reviewable) { Fabricate(:reviewable_queued_post_topic, category: category) }
      let(:user_stats) { reviewable.target_created_by.user_stat }

      context "when status changes from 'pending' to something else" do
        it "updates user stats" do
          user_stats.expects(:update_pending_posts)
          reviewable.update!(status: :approved)
        end
      end

      context "when status doesn’t change" do
        it "doesn’t update user stats" do
          user_stats.expects(:update_pending_posts).never
          reviewable.update!(score: 10)
        end
      end
    end
  end
end
