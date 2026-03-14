# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Flag do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:boost_id) }
    it { is_expected.to validate_presence_of(:flag_type_id) }

    it do
      is_expected.to validate_inclusion_of(:flag_type_id).in_array(ReviewableScore.types.values)
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
    end
  end
end
