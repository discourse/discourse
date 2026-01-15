# frozen_string_literal: true

require_relative "../fabricators/reaction_fabricator"
require_relative "../fabricators/reaction_user_fabricator"

RSpec.shared_examples "op_reactions_data serializer" do |serializer_class, modifier_name|
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:user_3, :user)
  fab!(:topic) { Fabricate(:topic, user: user_1) }
  fab!(:first_post) { Fabricate(:post, user: user_1, topic: topic, post_number: 1) }

  let(:plugin_instance) { Plugin::Instance.new }
  let(:modifier_block) { Proc.new { true } }

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "otter|+1|tada"
    SiteSetting.discourse_reactions_like_icon = "heart"

    plugin_instance.register_modifier(modifier_name, &modifier_block)
  end

  after do
    DiscoursePluginRegistry.unregister_modifier(plugin_instance, modifier_name, &modifier_block)
  end

  describe "#op_reactions_data" do
    context "when first_post is not loaded" do
      it "does not include op_reactions_data" do
        topic_without_first_post = Fabricate(:topic)
        json =
          serializer_class.new(
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
        DiscoursePluginRegistry.unregister_modifier(plugin_instance, modifier_name, &modifier_block)
        false_plugin_instance.register_modifier(modifier_name, &false_modifier_block)
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(
          false_plugin_instance,
          modifier_name,
          &false_modifier_block
        )
        plugin_instance.register_modifier(modifier_name, &modifier_block)
      end

      it "does not include op_reactions_data" do
        topic.association(:first_post).target = first_post
        json = serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json

        expect(json[:op_reactions_data]).to be_nil
      end
    end

    context "when first_post is loaded and modifier is true" do
      before do
        topic.association(:first_post).target = first_post
        first_post.post_actions_with_reaction_users =
          DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
            [first_post.id],
          )[
            first_post.id
          ]
      end

      it "includes all required fields" do
        json = serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json

        expect(json[:op_reactions_data]).to be_present
        expect(json[:op_reactions_data][:id]).to eq(first_post.id)
        expect(json[:op_reactions_data][:user_id]).to eq(user_1.id)
        expect(json[:op_reactions_data][:yours]).to eq(true)
        expect(json[:op_reactions_data]).to have_key(:reactions)
        expect(json[:op_reactions_data]).to have_key(:current_user_reaction)
        expect(json[:op_reactions_data]).to have_key(:current_user_used_main_reaction)
        expect(json[:op_reactions_data]).to have_key(:reaction_users_count)
        expect(json[:op_reactions_data]).to have_key(:likeAction)
      end

      it "shows yours as false for other users" do
        json = serializer_class.new(topic, scope: Guardian.new(user_2), root: false).as_json

        expect(json[:op_reactions_data][:yours]).to eq(false)
      end

      context "with reactions" do
        let(:reaction_otter) { Fabricate(:reaction, reaction_value: "otter", post: first_post) }
        let(:reaction_plus_1) { Fabricate(:reaction, reaction_value: "+1", post: first_post) }

        before do
          Fabricate(:reaction_user, reaction: reaction_otter, user: user_1, post: first_post)
          Fabricate(:reaction_user, reaction: reaction_otter, user: user_2, post: first_post)
          Fabricate(:reaction_user, reaction: reaction_plus_1, user: user_3, post: first_post)

          first_post.reload
          first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [first_post.id],
            )[
              first_post.id
            ]
        end

        it "includes reactions sorted by count and current user data" do
          json = serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json

          expect(json[:op_reactions_data][:reactions]).to eq(
            [{ id: "otter", type: :emoji, count: 2 }, { id: "+1", type: :emoji, count: 1 }],
          )
          expect(json[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "otter", type: :emoji, can_undo: true },
          )
          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
          expect(json[:op_reactions_data][:reaction_users_count]).to eq(3)
        end
      end

      context "with only likes" do
        before do
          Fabricate(
            :post_action,
            post: first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )

          first_post.reload
          first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [first_post.id],
            )[
              first_post.id
            ]
        end

        it "shows likes as main_reaction_id" do
          json = serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json

          expect(json[:op_reactions_data][:reactions]).to eq(
            [{ id: "heart", type: :emoji, count: 1 }],
          )
        end

        it "includes correct current_user_reaction based on user" do
          json_non_liker =
            serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json
          json_liker = serializer_class.new(topic, scope: Guardian.new(user_2), root: false).as_json

          expect(json_non_liker[:op_reactions_data][:current_user_reaction]).to be_nil
          expect(json_liker[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "heart", type: :emoji, can_undo: true },
          )
        end
      end

      context "with likeAction" do
        let!(:like_action) do
          Fabricate(
            :post_action,
            post: first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )
        end

        before do
          first_post.reload
          first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [first_post.id],
            )[
              first_post.id
            ]
        end

        it "shows canToggle correctly based on permissions and undo window" do
          json_with_like =
            serializer_class.new(topic, scope: Guardian.new(user_2), root: false).as_json
          json_without_like =
            serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json

          expect(json_with_like[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
          expect(json_without_like[:op_reactions_data][:likeAction][:canToggle]).to eq(true)

          SiteSetting.post_undo_action_window_mins = 10
          like_action.update!(created_at: 11.minutes.ago)

          json_expired =
            serializer_class.new(topic, scope: Guardian.new(user_2), root: false).as_json
          expect(json_expired[:op_reactions_data][:likeAction][:canToggle]).to eq(false)
        end
      end

      context "for anonymous users" do
        it "returns appropriate values for anonymous users" do
          json = serializer_class.new(topic, scope: Guardian.new(nil), root: false).as_json

          expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          expect(json[:op_reactions_data][:yours]).to eq(false)
          expect(json[:op_reactions_data][:current_user_used_main_reaction]).to eq(false)
          expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
          expect(json[:op_reactions_data][:id]).to eq(first_post.id)
          expect(json[:op_reactions_data][:user_id]).to eq(user_1.id)
        end

        context "with existing reactions from other users" do
          let(:reaction_otter) { Fabricate(:reaction, reaction_value: "otter", post: first_post) }
          let(:reaction_tada) { Fabricate(:reaction, reaction_value: "tada", post: first_post) }

          before do
            Fabricate(:reaction_user, reaction: reaction_otter, user: user_1, post: first_post)
            Fabricate(:reaction_user, reaction: reaction_otter, user: user_2, post: first_post)
            Fabricate(:reaction_user, reaction: reaction_tada, user: user_3, post: first_post)

            topic.reload
            topic.association(:first_post).target = first_post.reload
            first_post.post_actions_with_reaction_users =
              DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
                [first_post.id],
              )[
                first_post.id
              ]
          end

          it "can see all reactions and counts from other users" do
            json = serializer_class.new(topic, scope: Guardian.new(nil), root: false).as_json

            expect(json[:op_reactions_data][:reactions]).to match_array(
              [{ id: "otter", type: :emoji, count: 2 }, { id: "tada", type: :emoji, count: 1 }],
            )
            expect(json[:op_reactions_data][:reaction_users_count]).to eq(3)
            expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          end
        end

        context "with likes from other users" do
          before do
            Fabricate(
              :post_action,
              post: first_post,
              user: user_1,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )
            Fabricate(
              :post_action,
              post: first_post,
              user: user_2,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )

            topic.reload
            topic.association(:first_post).target = first_post.reload
            first_post.post_actions_with_reaction_users =
              DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
                [first_post.id],
              )[
                first_post.id
              ]
          end

          it "can see likes as main_reaction_id" do
            json = serializer_class.new(topic, scope: Guardian.new(nil), root: false).as_json

            expect(json[:op_reactions_data][:reactions]).to eq(
              [{ id: "heart", type: :emoji, count: 2 }],
            )
            expect(json[:op_reactions_data][:likeAction][:canToggle]).to eq(true)
            expect(json[:op_reactions_data][:current_user_reaction]).to be_nil
          end
        end
      end

      context "with mixed reactions and likes" do
        let(:reaction_otter) { Fabricate(:reaction, reaction_value: "otter", post: first_post) }

        before do
          Fabricate(:reaction_user, reaction: reaction_otter, user: user_1, post: first_post)
          Fabricate(
            :post_action,
            post: first_post,
            user: user_2,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )

          first_post.reload
          first_post.post_actions_with_reaction_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              [first_post.id],
            )[
              first_post.id
            ]
        end

        it "correctly combines reactions and likes with proper user states" do
          json_custom_reaction =
            serializer_class.new(topic, scope: Guardian.new(user_1), root: false).as_json
          json_main_reaction =
            serializer_class.new(topic, scope: Guardian.new(user_2), root: false).as_json

          expect(json_custom_reaction[:op_reactions_data][:reactions]).to match_array(
            [{ id: "otter", type: :emoji, count: 1 }, { id: "heart", type: :emoji, count: 1 }],
          )
          expect(json_custom_reaction[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "otter", type: :emoji, can_undo: true },
          )
          expect(json_custom_reaction[:op_reactions_data][:current_user_used_main_reaction]).to eq(
            false,
          )

          expect(json_main_reaction[:op_reactions_data][:current_user_reaction]).to eq(
            { id: "heart", type: :emoji, can_undo: true },
          )
          expect(json_main_reaction[:op_reactions_data][:current_user_used_main_reaction]).to eq(
            true,
          )
        end
      end
    end
  end
end

describe TopicListItemSerializer do
  include_examples "op_reactions_data serializer",
                   TopicListItemSerializer,
                   :include_discourse_reactions_data_on_topic_list
end

describe SuggestedTopicSerializer do
  include_examples "op_reactions_data serializer",
                   SuggestedTopicSerializer,
                   :include_discourse_reactions_data_on_suggested_topics
end
