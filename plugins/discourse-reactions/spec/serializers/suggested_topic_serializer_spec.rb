# frozen_string_literal: true

require_relative "../fabricators/reaction_fabricator"
require_relative "../fabricators/reaction_user_fabricator"

describe SuggestedTopicSerializer do
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:topic) { Fabricate(:topic, user: user_1) }
  fab!(:first_post) { Fabricate(:post, user: user_1, topic: topic, post_number: 1) }
  fab!(:suggested_topic) { Fabricate(:topic, user: user_2) }
  fab!(:suggested_first_post) do
    Fabricate(:post, user: user_2, topic: suggested_topic, post_number: 1)
  end

  let(:plugin_instance) { Plugin::Instance.new }
  let(:modifier_block) { Proc.new { true } }

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "otter|+1|tada"
    SiteSetting.discourse_reactions_like_icon = "heart"

    # Make sure the suggested topic will be suggested
    TopicUser.update_last_read(user_1, suggested_topic.id, 0, 0, 0)

    plugin_instance.register_modifier(
      :include_discourse_reactions_data_on_suggested_topics,
      &modifier_block
    )
  end

  after do
    DiscoursePluginRegistry.unregister_modifier(
      plugin_instance,
      :include_discourse_reactions_data_on_suggested_topics,
      &modifier_block
    )
  end

  describe "#op_reactions_data" do
    context "when first_post is not loaded" do
      it "does not include op_reactions_data" do
        topic_without_first_post = Fabricate(:topic)
        json =
          SuggestedTopicSerializer.new(
            topic_without_first_post,
            scope: Guardian.new(user_1),
            root: false,
          ).as_json

        expect(json[:op_reactions_data]).to be_nil
      end
    end

    context "when modifier returns false" do
      let(:false_plugin_instance) { Plugin::Instance.new }
      let(:false_modifier_block) { Proc.new { false } }

      before do
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :include_discourse_reactions_data_on_suggested_topics,
          &modifier_block
        )
        false_plugin_instance.register_modifier(
          :include_discourse_reactions_data_on_suggested_topics,
          &false_modifier_block
        )
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(
          false_plugin_instance,
          :include_discourse_reactions_data_on_suggested_topics,
          &false_modifier_block
        )
        # Re-register the original modifier for subsequent tests
        plugin_instance.register_modifier(
          :include_discourse_reactions_data_on_suggested_topics,
          &modifier_block
        )
      end

      it "does not include op_reactions_data" do
        suggested_topic.association(:first_post).target = suggested_first_post
        json =
          SuggestedTopicSerializer.new(
            suggested_topic,
            scope: Guardian.new(user_1),
            root: false,
          ).as_json

        expect(json[:op_reactions_data]).to be_nil
      end
    end

    context "when first_post is loaded and modifier is true" do
      before do
        suggested_topic.association(:first_post).target = suggested_first_post
        suggested_first_post.post_actions_with_reaction_users =
          DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
            [suggested_first_post.id],
          )[
            suggested_first_post.id
          ]
      end

      it "includes basic post information" do
        json =
          SuggestedTopicSerializer.new(
            suggested_topic,
            scope: Guardian.new(user_1),
            root: false,
          ).as_json

        expect(json[:op_reactions_data]).to be_present
        expect(json[:op_reactions_data][:id]).to eq(suggested_first_post.id)
        expect(json[:op_reactions_data][:user_id]).to eq(user_2.id)
        expect(json[:op_reactions_data][:yours]).to eq(false)
      end

      it "shows yours as true for post author" do
        json =
          SuggestedTopicSerializer.new(
            suggested_topic,
            scope: Guardian.new(user_2),
            root: false,
          ).as_json

        expect(json[:op_reactions_data][:yours]).to eq(true)
      end

      context "with reactions" do
        let(:reaction_otter) do
          Fabricate(:reaction, reaction_value: "otter", post: suggested_first_post)
        end
        let(:reaction_plus_1) do
          Fabricate(:reaction, reaction_value: "+1", post: suggested_first_post)
        end

        before do
          Fabricate(
            :reaction_user,
            reaction: reaction_otter,
            user: user_1,
            post: suggested_first_post,
          )
          Fabricate(
            :reaction_user,
            reaction: reaction_otter,
            user: user_2,
            post: suggested_first_post,
          )
          Fabricate(
            :reaction_user,
            reaction: reaction_plus_1,
            user: user_3,
            post: suggested_first_post,
          )

          suggested_first_post.reload
          suggested_first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [suggested_first_post.id],
            )[
              suggested_first_post.id
            ]
        end

        it "includes reactions sorted by count" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          # otter has 2 users, +1 has 1 user
          expect(json[:op_reactions_data][:reactions]).to eq(
            [{ id: "otter", type: :emoji, count: 2 }, { id: "+1", type: :emoji, count: 1 }],
          )
        end

        it "includes current_user_reaction for reacting user" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "otter", type: :emoji, can_undo: true },
          )
        end

        it "includes current_user_used_main_reaction" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          # User 1 used "otter" reaction, not the main reaction "heart"
          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
        end

        it "includes reaction_users_count" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          # 3 reaction users: user_1 and user_2 for otter, user_3 for +1
          expect(json[:op_reactions_data][:reaction_users_count]).to eq(3)
        end
      end

      context "with only likes (no custom reactions)" do
        before do
          Fabricate(
            :post_action,
            post: suggested_first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )

          suggested_first_post.reload
          suggested_first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [suggested_first_post.id],
            )[
              suggested_first_post.id
            ]
        end

        it "shows likes as main_reaction_id" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:reactions]).to eq(
            [{ id: "heart", type: :emoji, count: 1 }],
          )
        end

        it "includes current_user_reaction as nil for non-liking user" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
        end

        it "includes current_user_reaction for liking user" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_2),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "heart", type: :emoji, can_undo: true },
          )
        end
      end

      context "with likeAction" do
        let!(:like_action) do
          Fabricate(
            :post_action,
            post: suggested_first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )
        end

        before do
          suggested_first_post.reload
          suggested_first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [suggested_first_post.id],
            )[
              suggested_first_post.id
            ]
        end

        it "shows canToggle as true when user has a like action they can delete" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_2),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
        end

        it "shows canToggle as true when user has no like action" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
        end

        it "shows canToggle as false when user cannot delete their like action" do
          SiteSetting.post_undo_action_window_mins = 10
          like_action.update!(created_at: 11.minutes.ago)

          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_2),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(false)
        end
      end

      context "for anonymous users" do
        it "returns nil for current_user_reaction" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(nil),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          expect(json[:op_reactions_data][:yours]).to eq(false)
          expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
        end

        it "shows current_user_used_main_reaction as false" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(nil),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
        end

        it "includes basic post data regardless of reactions" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(nil),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:id]).to eq(suggested_first_post.id)
          expect(json[:op_reactions_data][:user_id]).to eq(user_2.id)
          expect(json[:op_reactions_data][:yours]).to eq(false)
        end

        context "with existing reactions from other users" do
          let(:reaction_otter) do
            Fabricate(:reaction, reaction_value: "otter", post: suggested_first_post)
          end
          let(:reaction_tada) do
            Fabricate(:reaction, reaction_value: "tada", post: suggested_first_post)
          end

          before do
            Fabricate(
              :reaction_user,
              reaction: reaction_otter,
              user: user_1,
              post: suggested_first_post,
            )
            Fabricate(
              :reaction_user,
              reaction: reaction_otter,
              user: user_2,
              post: suggested_first_post,
            )
            Fabricate(
              :reaction_user,
              reaction: reaction_tada,
              user: user_3,
              post: suggested_first_post,
            )

            suggested_topic.reload
            suggested_topic.association(:first_post).target = suggested_first_post.reload
            suggested_first_post.post_actions_with_reaction_users =
              DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
                [suggested_first_post.id],
              )[
                suggested_first_post.id
              ]
          end

          it "can see all reactions from other users" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:reactions]).to match_array(
              [{ id: "otter", type: :emoji, count: 2 }, { id: "tada", type: :emoji, count: 1 }],
            )
          end

          it "can see the reaction_users_count" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:reaction_users_count]).to eq(3)
          end

          it "does not show any current_user_reaction" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          end

          it "shows current_user_used_main_reaction as false" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
          end
        end

        context "with likes from other users" do
          before do
            Fabricate(
              :post_action,
              post: suggested_first_post,
              user: user_1,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )
            Fabricate(
              :post_action,
              post: suggested_first_post,
              user: user_2,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )

            suggested_topic.reload
            suggested_topic.association(:first_post).target = suggested_first_post.reload
            suggested_first_post.post_actions_with_reaction_users =
              DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
                [suggested_first_post.id],
              )[
                suggested_first_post.id
              ]
          end

          it "can see likes as main_reaction_id" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:reactions]).to eq(
              [{ id: "heart", type: :emoji, count: 2 }],
            )
          end

          it "shows canToggle as true even without being logged in" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
          end

          it "does not show current_user_reaction" do
            json =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(nil),
                root: false,
              ).as_json

            expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          end
        end
      end

      context "with mixed reactions and likes" do
        let(:reaction_otter) do
          Fabricate(:reaction, reaction_value: "otter", post: suggested_first_post)
        end

        before do
          # User 1 uses custom reaction (otter counts as a like, so it will create a PostAction)
          Fabricate(
            :reaction_user,
            reaction: reaction_otter,
            user: user_1,
            post: suggested_first_post,
          )

          # User 2 uses main reaction (like) - manually create just the PostAction
          Fabricate(
            :post_action,
            post: suggested_first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )

          suggested_first_post.reload
          suggested_first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [suggested_first_post.id],
            )[
              suggested_first_post.id
            ]
        end

        it "correctly combines reactions and likes" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          # User 1 has otter reaction (counts as like)
          # User 2 has main reaction (PostAction only, no ReactionUser)
          expect(json[:op_reactions_data][:reactions]).to match_array(
            [{ id: "otter", type: :emoji, count: 1 }, { id: "heart", type: :emoji, count: 1 }],
          )
        end

        it "shows correct current_user_reaction for user with custom reaction" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_1),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "otter", type: :emoji, can_undo: true },
          )
          # User 1 used otter, not the main reaction
          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
        end

        it "shows correct current_user_reaction for user with main reaction" do
          json =
            SuggestedTopicSerializer.new(
              suggested_topic,
              scope: Guardian.new(user_2),
              root: false,
            ).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "heart", type: :emoji, can_undo: true },
          )
          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(true)
        end
      end

      it "returns true when first_post is loaded and modifier returns true" do
        suggested_topic.association(:first_post).target = suggested_first_post
        suggested_first_post.post_actions_with_reaction_users =
          DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
            [suggested_first_post.id],
          )[
            suggested_first_post.id
          ]

        json =
          SuggestedTopicSerializer.new(
            suggested_topic,
            scope: Guardian.new(user_1),
            root: false,
          ).as_json

        expect(json.key?(:op_reactions_data)).to eq(true)
      end
    end
  end
end
