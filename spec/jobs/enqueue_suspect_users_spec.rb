# frozen_string_literal: true

require 'rails_helper'

describe Jobs::EnqueueSuspectUsers do
  before { SiteSetting.approve_suspect_users = true }

  it 'does nothing when there are no suspect users' do
    subject.execute({})

    expect(ReviewableUser.count).to be_zero
  end

  context 'with suspect users' do
    fab!(:suspect_user) { Fabricate(:active_user, created_at: 1.day.ago) }

    it 'creates a reviewable when there is a suspect user' do
      subject.execute({})

      expect(ReviewableUser.count).to eq(1)
    end

    it 'only creates one reviewable per user' do
      review_user = ReviewableUser.needs_review!(
        target: suspect_user,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true
      )

      subject.execute({})

      expect(ReviewableUser.count).to eq(1)
      expect(ReviewableUser.last).to eq(review_user)
    end

    it 'adds a score' do
      subject.execute({})
      score = ReviewableScore.last

      expect(score.reason).to eq('suspect_user')
    end
  end
end
