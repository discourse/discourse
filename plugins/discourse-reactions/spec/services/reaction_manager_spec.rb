# frozen_string_literal: true

RSpec.describe DiscourseReactions::ReactionManager do
  def reaction_manager(reaction_value)
    described_class.new(reaction_value: reaction_value, user: user, post: post)
  end

  fab!(:user)
  fab!(:post)
  fab!(:reaction_plus_one) { Fabricate(:reaction, reaction_value: "+1", post: post) }
  fab!(:reaction_minus_one) { Fabricate(:reaction, reaction_value: "-1", post: post) }
  fab!(:reaction_clap) { Fabricate(:reaction, reaction_value: "clap", post: post) }
  fab!(:reaction_hugs) { Fabricate(:reaction, reaction_value: "hugs", post: post) }

  before { SiteSetting.discourse_reactions_reaction_for_like = "clap" }

  describe ".toggle!" do
    context "when the user has not yet reacted to the post" do
      context "when the new reaction matches discourse_reactions_reaction_for_like" do
        it "does create a PostAction record" do
          expect { reaction_manager("clap").toggle! }.to change { PostAction.count }.by(1)
        end

        it "does not create a ReactionUser record" do
          expect { reaction_manager("clap").toggle! }.not_to change {
            DiscourseReactions::ReactionUser.count
          }
        end

        it "creates a reaction notification" do
          expect { reaction_manager("clap").toggle! }.to change { Notification.count }.by(1)
        end
      end

      context "when the new reaction does not match discourse_reactions_reaction_for_like" do
        it "does create a PostAction record" do
          expect { reaction_manager("+1").toggle! }.to change { PostAction.count }
        end

        it "does create a ReactionUser record" do
          expect { reaction_manager("+1").toggle! }.to change {
            DiscourseReactions::ReactionUser.count
          }
        end

        it "creates a reaction notification" do
          expect { reaction_manager("+1").toggle! }.to change { Notification.count }.by(1)
        end

        context "when the reaction is in discourse_reactions_excluded_from_like" do
          before { SiteSetting.discourse_reactions_excluded_from_like = "+1" }

          it "does not create a PostAction record" do
            expect { reaction_manager("+1").toggle! }.not_to change { PostAction.count }
          end
        end
      end
    end

    context "when the user already reacted to the Post" do
      context "when the existing reaction was a ReactionUser" do
        let!(:reaction_user) do
          Fabricate(:reaction_user, user: user, post: post, reaction: reaction_plus_one)
        end

        context "when the user has permission to delete the ReactionUser" do
          it "removes the ReactionUser for the old +1 reaction" do
            reaction_manager("-1").toggle!
            expect(DiscourseReactions::ReactionUser.find_by(id: reaction_user.id)).to be_nil
          end

          it "removes any PostAction that exists as well" do
            expect { reaction_manager("-1").toggle! }.to change { PostAction.count }.by(-1)
          end

          it "adds a new ReactionUser record for the new reaction -1 but not PostAction because of discourse_reactions_excluded_from_like" do
            reaction_manager("-1").toggle!
            expect(
              DiscourseReactions::ReactionUser.find_by(
                reaction: reaction_minus_one,
                user: user,
                post: post,
              ),
            ).to be_present
            expect(
              PostAction.find_by(
                post: post,
                user: user,
                post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
              ),
            ).to be_nil
          end

          it "adds a new ReactionUser record and a PostAction record for reaction hugs" do
            reaction_manager("hugs").toggle!
            expect(
              DiscourseReactions::ReactionUser.find_by(
                reaction: reaction_hugs,
                user: user,
                post: post,
              ),
            ).to be_present
            expect(
              PostAction.find_by(
                post: post,
                user: user,
                post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
              ),
            ).to be_present
          end

          it "deletes any notifications for the old Reaction and creates a notification for the new reaction" do
            DiscourseReactions::ReactionNotification.new(reaction_plus_one, user).create
            expect { reaction_manager("-1").toggle! }.not_to change { Notification.count }
            expect(
              Notification.where(
                notification_type: Notification.types[:reaction],
                topic_id: post.topic_id,
                user_id: post.user_id,
                post_number: post.post_number,
              ).count,
            ).to eq(1)
          end

          it "removes the Reaction record attached to the post when no more users have reacted to it" do
            expect { reaction_manager("-1").toggle! }.to change {
              DiscourseReactions::Reaction.where(id: reaction_plus_one).count
            }.by(-1)
          end

          context "when the previous reaction is the same as the new one" do
            before { reaction_user.update!(reaction: reaction_minus_one) }

            it "does not add a new ReactionUser record, just removes the old one" do
              expect { reaction_manager("-1").toggle! }.to change {
                DiscourseReactions::ReactionUser.count
              }.by(-1).and change { PostAction.count }.by(-1)
            end
          end
        end

        context "when the user does not have permission to delete the ReactionUser" do
          before do
            reaction_user.update!(
              created_at: Time.zone.now - (SiteSetting.post_undo_action_window_mins + 1).minutes,
            )
          end

          it "raises an error" do
            expect { reaction_manager("-1").toggle! }.to raise_error(Discourse::InvalidAccess)
          end
        end
      end

      context "when the existing reaction counted as a PostAction (Like) without a matching ReactionUser" do
        let!(:post_action) do
          Fabricate(
            :post_action,
            post: post,
            user: user,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )
        end

        context "when the user has permission to delete the PostAction" do
          it "removes the PostAction" do
            expect { reaction_manager("-1").toggle! }.to change { PostAction.count }.by(-1)
          end

          it "removes the Reaction record attached to the post" do
            expect { reaction_manager("-1").toggle! }.to change {
              DiscourseReactions::Reaction.where(id: reaction_clap).count
            }.by(-1)
          end

          it "deletes any notifications for the old Reaction and creates a notification for the new reaction" do
            DiscourseReactions::ReactionNotification.new(reaction_clap, user).create
            expect { reaction_manager("-1").toggle! }.not_to change { Notification.count }
            expect(
              Notification.where(
                notification_type: Notification.types[:reaction],
                topic_id: post.topic_id,
                user_id: post.user_id,
                post_number: post.post_number,
              ).count,
            ).to eq(1)
          end
        end

        context "when the user does not have permission to delete the PostAction" do
          before do
            post_action.update!(
              created_at: Time.zone.now - (SiteSetting.post_undo_action_window_mins + 1).minutes,
            )
          end

          it "raises an error" do
            expect { reaction_manager("-1").toggle! }.to raise_error(Discourse::InvalidAccess)
          end
        end
      end
    end
  end
end
