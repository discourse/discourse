# frozen_string_literal: true

RSpec.describe User::Action::TriggerPostAction do
  describe ".call" do
    subject(:action) { described_class.call(guardian:, post:, params:) }

    fab!(:post)
    fab!(:admin)

    let(:guardian) { admin.guardian }
    let(:params) { User::Suspend::Contract.new(post_action:, post_edit:) }
    let(:post_action) { nil }
    let(:post_edit) { nil }

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

        it "edits the post with what the moderator wrote" do
          expect { action }.to change { post.reload.raw }.to eq("blabla")
        end
      end
    end
  end
end
