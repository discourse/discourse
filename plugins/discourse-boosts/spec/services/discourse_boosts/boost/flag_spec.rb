# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Flag do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:boost_id) }
    it { is_expected.to validate_presence_of(:flag_type_id) }

    it do
      is_expected.to validate_inclusion_of(:flag_type_id).in_array(
        Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:id),
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:flagger, :user)
    fab!(:post_author, :user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:, user: post_author) }
    fab!(:boost) { Fabricate(:boost, post:, user: post_author) }

    let(:params) { { boost_id: boost.id, flag_type_id: ReviewableScore.types[:spam] } }
    let(:dependencies) { { guardian: flagger.guardian } }

    context "when contract is invalid" do
      let(:params) { { boost_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when boost is not found" do
      let(:params) { { boost_id: 0, flag_type_id: ReviewableScore.types[:spam] } }

      it { is_expected.to fail_to_find_a_model(:boost) }
    end

    context "when user flags their own boost" do
      let(:dependencies) { { guardian: post_author.guardian } }

      it { is_expected.to fail_a_policy(:can_flag_boost) }
    end

    context "when user is silenced" do
      before { flagger.update!(silenced_till: 1.year.from_now) }

      it { is_expected.to fail_a_policy(:can_flag_boost) }
    end

    context "when boost author is staff and allow_flagging_staff is disabled" do
      before do
        post_author.update!(admin: true)
        SiteSetting.allow_flagging_staff = false
      end

      it { is_expected.to fail_a_policy(:can_flag_boost) }
    end

    context "when flag type does not apply to boosts" do
      let(:params) { { boost_id: boost.id, flag_type_id: ReviewableScore.types[:needs_approval] } }

      it { is_expected.to fail_a_contract }
    end

    context "when user already has a pending flag on the boost" do
      before do
        reviewable =
          DiscourseBoosts::ReviewableBoost.needs_review!(
            created_by: flagger,
            target: boost,
            target_created_by: boost.user,
            reviewable_by_moderator: true,
          )
        reviewable.add_score(flagger, ReviewableScore.types[:spam])
      end

      it { is_expected.to fail_a_policy(:can_flag_again) }
    end

    context "when flag type already has a pending score" do
      fab!(:other_flagger, :user)

      before do
        reviewable =
          DiscourseBoosts::ReviewableBoost.needs_review!(
            created_by: other_flagger,
            target: boost,
            target_created_by: boost.user,
            reviewable_by_moderator: true,
          )
        reviewable.add_score(other_flagger, ReviewableScore.types[:spam])
      end

      it { is_expected.to fail_a_policy(:can_flag_again) }
    end

    context "when reviewable was recently handled" do
      fab!(:other_flagger, :user)

      before do
        reviewable =
          DiscourseBoosts::ReviewableBoost.needs_review!(
            created_by: other_flagger,
            target: boost,
            target_created_by: boost.user,
            reviewable_by_moderator: true,
          )
        reviewable.add_score(other_flagger, ReviewableScore.types[:off_topic])
        reviewable.update!(status: Reviewable.statuses[:rejected], updated_at: 1.minute.ago)
        reviewable.reviewable_scores.update_all(status: ReviewableScore.statuses[:disagreed])
      end

      let(:params) { { boost_id: boost.id, flag_type_id: ReviewableScore.types[:off_topic] } }

      it { is_expected.to fail_a_policy(:can_flag_again) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a reviewable targeting the boost" do
        expect { result }.to change { DiscourseBoosts::ReviewableBoost.count }.by(1)

        reviewable = DiscourseBoosts::ReviewableBoost.last
        expect(reviewable).to have_attributes(
          target: boost,
          created_by: flagger,
          target_created_by: post_author,
          reviewable_by_moderator: true,
          topic: topic,
          category_id: topic.category_id,
        )
        expect(reviewable.payload["boost_cooked"]).to eq(boost.cooked)
      end

      it "adds a score to the reviewable" do
        expect { result }.to change { ReviewableScore.count }.by(1)

        score = ReviewableScore.last
        expect(score).to have_attributes(
          user: flagger,
          reviewable_score_type: ReviewableScore.types[:spam],
        )
      end

      context "when flagging as spam" do
        it "marks the reviewable as potential spam" do
          result
          expect(DiscourseBoosts::ReviewableBoost.last).to be_potential_spam
        end
      end

      context "when flagging as off-topic" do
        let(:params) { { boost_id: boost.id, flag_type_id: ReviewableScore.types[:off_topic] } }

        it "does not mark the reviewable as potential spam" do
          result
          expect(DiscourseBoosts::ReviewableBoost.last).not_to be_potential_spam
        end
      end

      context "when flagging with a message as notify_moderators" do
        let(:params) do
          {
            boost_id: boost.id,
            flag_type_id: ReviewableScore.types[:notify_moderators],
            message: "This boost is problematic",
          }
        end

        it "creates a companion PM to moderators" do
          expect { result }.to change {
            Topic.where(archetype: Archetype.private_message).count
          }.by(1)

          pm_topic = Topic.where(archetype: Archetype.private_message).last
          expect(pm_topic.subtype).to eq(TopicSubtype.notify_moderators)
          expect(pm_topic.first_post.raw).to include("This boost is problematic")
        end

        it "stores the companion PM topic_id on the reviewable score" do
          result
          score = ReviewableScore.last
          expect(score.meta_topic_id).to be_present
        end
      end

      context "when flagging with a message as illegal" do
        let(:params) do
          {
            boost_id: boost.id,
            flag_type_id: ReviewableScore.types[:illegal],
            message: "This violates the law",
          }
        end

        it "creates a companion PM to moderators" do
          expect { result }.to change {
            Topic.where(archetype: Archetype.private_message).count
          }.by(1)

          pm_topic = Topic.where(archetype: Archetype.private_message).last
          expect(pm_topic.first_post.raw).to include("This violates the law")
        end
      end

      context "when take_action is true" do
        fab!(:staff_flagger, :moderator)

        let(:dependencies) { { guardian: staff_flagger.guardian } }
        let(:params) do
          { boost_id: boost.id, flag_type_id: ReviewableScore.types[:spam], take_action: true }
        end

        it "auto-approves the reviewable and deletes the boost" do
          result
          reviewable = DiscourseBoosts::ReviewableBoost.last
          expect(reviewable).to be_approved
          expect(DiscourseBoosts::Boost.find_by(id: boost.id)).to be_nil
        end

        it "gives the score a take_action bonus" do
          result
          score = ReviewableScore.last
          expect(score.take_action_bonus).to be > 0
        end
      end

      context "when a non-staff user attempts take_action" do
        let(:params) do
          { boost_id: boost.id, flag_type_id: ReviewableScore.types[:spam], take_action: true }
        end

        it { is_expected.to fail_a_policy(:can_flag_boost) }
      end

      context "when queue_for_review is true" do
        fab!(:staff_flagger, :moderator)

        let(:dependencies) { { guardian: staff_flagger.guardian } }
        let(:params) do
          { boost_id: boost.id, flag_type_id: ReviewableScore.types[:spam], queue_for_review: true }
        end

        it "sets force_review and reason on the score" do
          result
          score = ReviewableScore.last
          expect(score.reason).to eq("boost_queued_by_staff")
        end

        it "creates the reviewable with force_review" do
          result
          reviewable = DiscourseBoosts::ReviewableBoost.last
          expect(reviewable).to be_force_review
        end
      end

      context "when a non-staff user attempts queue_for_review" do
        let(:params) do
          { boost_id: boost.id, flag_type_id: ReviewableScore.types[:spam], queue_for_review: true }
        end

        it { is_expected.to fail_a_policy(:can_flag_boost) }
      end
    end
  end
end
