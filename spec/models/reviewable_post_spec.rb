# frozen_string_literal: true

RSpec.describe ReviewablePost do
  fab!(:admin)

  describe ".queue_for_media_review_if_possible" do
    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:post) { Fabricate(:post, user: author, raw: "this is a plain text post") }

    let(:image_markdown) { "![image](upload://sherlock.jpeg)" }
    let(:other_image_markdown) { "![image](upload://moriarty.jpeg)" }

    before { SiteSetting.skip_review_media_groups = Group::AUTO_GROUPS[:trust_level_3] }

    def queue(raw, editor: author, previous_raw: post.raw)
      post.raw = raw
      described_class.queue_for_media_review_if_possible(post, editor, previous_raw:)
    end

    it "queues the post when an edit adds media" do
      expect { queue("#{post.raw}\n\n#{image_markdown}") }.to change(ReviewablePost, :count).by(1)

      reviewable = ReviewablePost.last
      expect(reviewable.target).to eq(post)
      expect(reviewable).to be_pending
      expect(reviewable.reviewable_scores.last.reason).to eq("contains_media")
    end

    it "queues the post when an edit replaces the media" do
      expect { queue(other_image_markdown, previous_raw: image_markdown) }.to change(
        ReviewablePost,
        :count,
      ).by(1)
    end

    it "queues the post even when a flag is already pending" do
      Fabricate(:reviewable_flagged_post, target: post, topic: post.topic)

      expect { queue("#{post.raw}\n\n#{image_markdown}") }.to change(ReviewablePost, :count).by(1)
    end

    it "does not queue the post when the raw is unchanged" do
      expect { queue(post.raw) }.not_to change(ReviewablePost, :count)
    end

    it "does not queue the post when the edit leaves the media alone" do
      expect {
        queue("behold: #{image_markdown}", previous_raw: "look: #{image_markdown}")
      }.not_to change(ReviewablePost, :count)
    end

    it "does not queue the post when the edit removes the media" do
      expect { queue("no more media", previous_raw: image_markdown) }.not_to change(
        ReviewablePost,
        :count,
      )
    end

    it "does not queue the post when the editor is a staff member" do
      expect { queue("#{post.raw}\n\n#{image_markdown}", editor: admin) }.not_to change(
        ReviewablePost,
        :count,
      )
    end

    it "does not queue the post when the editor is a bot" do
      expect { queue("#{post.raw}\n\n#{image_markdown}", editor: Fabricate(:bot)) }.not_to change(
        ReviewablePost,
        :count,
      )
    end

    it "does not queue the post when the editor is in a skip group" do
      SiteSetting.skip_review_media_groups = Group::AUTO_GROUPS[:trust_level_1]

      expect { queue("#{post.raw}\n\n#{image_markdown}") }.not_to change(ReviewablePost, :count)
    end

    it "does not score the post again when a media reviewable is already pending" do
      reviewable = described_class.queue_for_review(post)

      expect { queue("#{post.raw}\n\n#{image_markdown}") }.not_to change {
        reviewable.reload.reviewable_scores.count
      }
    end

    it "does not queue the post when it is not a regular post" do
      post.update!(post_type: Post.types[:whisper])

      expect { queue("#{post.raw}\n\n#{image_markdown}") }.not_to change(ReviewablePost, :count)
    end

    it "does not queue the post when it is in a private message" do
      pm_post = Fabricate(:private_message_post, user: author)
      previous_raw = pm_post.raw
      pm_post.raw = "#{previous_raw}\n\n#{image_markdown}"

      expect {
        described_class.queue_for_media_review_if_possible(pm_post, author, previous_raw:)
      }.not_to change(ReviewablePost, :count)
    end
  end

  describe "#build_actions" do
    let(:post) { Fabricate.build(:post) }
    let(:reviewable) { ReviewablePost.new(target: post, target_created_by: post.user) }
    let(:guardian) { Guardian.new }

    it "Does not return available actions when the reviewable is no longer pending" do
      available_actions =
        (Reviewable.statuses.keys - ["pending"]).reduce([]) do |actions, status|
          reviewable.status = status

          actions.concat reviewable_actions(guardian).to_a
        end

      expect(available_actions).to be_empty
    end

    it "only shows the approve post action if users cannot delete the post" do
      expect(reviewable_actions(guardian).has?(:approve)).to eq(true)
      expect(reviewable_actions(guardian).has?(:reject_and_delete)).to eq(false)
    end

    it "includes the reject and delete action if the user is allowed" do
      expect(reviewable_actions(Guardian.new(admin)).has?(:reject_and_delete)).to eq(true)
    end

    it "includes the approve post and unhide action if the post is hidden" do
      post.hidden = true

      actions = reviewable_actions(guardian)

      expect(actions.has?(:approve_and_unhide)).to eq(true)
    end

    it "includes the reject post and keep deleted action is the post is deleted" do
      post.deleted_at = 1.day.ago

      actions = reviewable_actions(guardian)

      expect(actions.has?(:approve_and_restore)).to eq(false)
      expect(actions.has?(:reject_and_keep_deleted)).to eq(true)
    end

    it "includes an option to approve and restore the post if the user is allowed" do
      post.deleted_at = 1.day.ago

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:approve_and_restore)).to eq(false)
    end

    it "doesn't include the suspend action when the author is already suspended" do
      post.user.suspended_till = 1.year.from_now
      post.user.suspended_at = Time.zone.now

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:reject_and_suspend)).to eq(false)
      expect(actions.has?(:reject_and_silence)).to eq(true)
    end

    it "doesn't include the silence action when the author is already silenced" do
      post.user.silenced_till = 1.year.from_now

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:reject_and_suspend)).to eq(true)
      expect(actions.has?(:reject_and_silence)).to eq(false)
    end

    def reviewable_actions(guardian)
      actions = Reviewable::Actions.new(reviewable, guardian, {})
      reviewable.build_actions(actions, guardian, {})

      actions
    end
  end

  describe "Performing actions" do
    let(:post) { Fabricate(:post) }
    let(:reviewable) { ReviewablePost.needs_review!(target: post, created_by: admin) }

    before { reviewable.created_new! }

    describe "#perform_approve" do
      it "transitions to the approved state" do
        result = reviewable.perform admin, :approve

        expect(result.transition_to).to eq :approved
      end
    end

    describe "#perform_reject_and_suspend" do
      it "transitions to the rejected state" do
        result = reviewable.perform admin, :reject_and_suspend

        expect(result.transition_to).to eq :rejected
      end
    end

    describe "#perform_reject_and_keep_deleted" do
      it "transitions to the rejected state and keep the post deleted" do
        post.trash!

        result = reviewable.perform admin, :reject_and_keep_deleted

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
      end
    end

    describe "#perform_approve_and_restore" do
      it "transitions to the approved state and restores the post" do
        post.trash!

        result = reviewable.reload.perform admin, :approve_and_restore

        expect(result.transition_to).to eq :approved
        expect(Post.where(id: post.id).exists?).to eq(true)
      end
    end

    describe "#perform_approve_and_unhide" do
      it "transitions to the approved state and unhides the post" do
        post.update!(hidden: true)

        result = reviewable.reload.perform admin, :approve_and_unhide

        expect(result.transition_to).to eq :approved
        expect(post.reload.hidden).to eq(false)
      end
    end

    describe "#perform_reject_and_delete" do
      it "transitions to the rejected state and deletes the post" do
        result = reviewable.perform admin, :reject_and_delete

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
      end
    end
  end
end
