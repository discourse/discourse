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

    it 'only enqueues non-approved users' do
      suspect_user.update!(approved: true)

      subject.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it 'does nothing if must_approve_users is set to true' do
      SiteSetting.must_approve_users = true
      suspect_user.update!(approved: false)

      subject.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it 'ignores users created more than six months ago' do
      suspect_user.update!(created_at: 1.year.ago)

      subject.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it 'ignores users that were imported from another site' do
      suspect_user.upsert_custom_fields({ import_id: 'fake_id' })

      subject.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(false)
    end

    it 'enqueues a suspect users with custom fields' do
      suspect_user.upsert_custom_fields({ field_a: 'value', field_b: 'value' })

      subject.execute({})

      expect(ReviewableUser.where(target: suspect_user).exists?).to eq(true)
    end
  end
end
