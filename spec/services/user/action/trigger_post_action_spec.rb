# frozen_string_literal: true

RSpec.describe User::Action::TriggerPostAction do
  describe ".call" do
    subject(:action) { described_class.call(guardian:, post:, params:, raise_on_failure:) }

    fab!(:post)
    fab!(:admin)

    let(:guardian) { admin.guardian }
    let(:params) { User::Suspend::Contract.new(post_action:, post_edit:) }
    let(:post_action) { nil }
    let(:post_edit) { nil }
    let(:raise_on_failure) { false }

    context "when post is blank" do
      let(:post) { nil }

      it "does nothing" do
        expect { action }.not_to change { Post.count }
      end
    end

    context "when post_action is blank" do
      it "does nothing" do
        expect { action }.not_to change { Post.count }
      end
    end

    context "when post_action is 'none'" do
      let(:post_action) { "none" }

      it "does nothing" do
        expect { action }.not_to change { Post.count }
      end
    end

    context "when bulk deletion is selected during a review" do
      let(:post_action) { "delete_all" }
      let(:raise_on_failure) { true }

      it "leaves the post for the separate bulk deletion" do
        expect { action }.not_to change { post.reload.deleted_at }
      end
    end

    context "when a review selects a deletion the actor cannot perform" do
      let(:post_action) { "delete" }
      let(:guardian) { Guardian.new }
      let(:raise_on_failure) { true }

      it "rejects the deletion" do
        expect { action }.to raise_error(Discourse::InvalidAccess)
        expect(post.reload).not_to be_trashed
      end
    end

    context "when a review edit leaves the post unchanged" do
      let(:post_action) { "edit" }
      let(:post_edit) { "#{post.raw}  " }
      let(:raise_on_failure) { true }

      it "accepts the edit without creating a revision" do
        expect { action }.not_to change { post.revisions.count }
        expect(post.reload.raw).to eq(post_edit.strip)
      end
    end

    context "when post and post_action are defined" do
      context "when post_action is 'delete'" do
        let(:post_action) { "delete" }

        context "when user cannot delete a post" do
          let(:guardian) { Guardian.new }

          it "does nothing" do
            expect { action }.not_to change { Post.count }
          end
        end

        context "when user can delete a post" do
          it "deletes the provided post" do
            expect { action }.to change { Post.where(id: post.id).count }.by(-1)
          end
        end
      end

      context "when post_action is 'delete_replies'" do
        let(:post_action) { "delete_replies" }

        context "when user cannot delete a post" do
          let(:guardian) { Guardian.new }

          it "does nothing" do
            expect { action }.not_to change { Post.count }
          end
        end

        context "when user can delete a post" do
          fab!(:reply) do
            Fabricate(:reply, topic: post.topic, reply_to_post_number: post.post_number)
          end

          before { post.replies << reply }

          it "deletes the provided post" do
            expect { action }.to change { Post.where(id: post.id).count }.by(-1)
          end

          it "deletes the post's replies" do
            expect { action }.to change { Post.where(id: reply.id).count }.by(-1)
          end
        end
      end

      context "when post_action is 'edit'" do
        let(:post_action) { "edit" }
        let(:post_edit) { "blabla" }

        context "when user cannot edit a post" do
          fab!(:regular_user, :user)
          let(:guardian) { regular_user.guardian }

          it "does nothing" do
            expect { action }.not_to change { post.reload.raw }
          end
        end

        context "when user can edit a post" do
          it "edits the post with what the moderator wrote" do
            expect { action }.to change { post.reload.raw }.to eq("blabla")
          end
        end
      end
    end
  end
end
