require 'rails_helper'

describe TopicFeaturedUsers do
  it 'ensures consistency' do

    t = Fabricate(:topic)
    Fabricate(:post, topic: t, user: t.user)
    p2 = Fabricate(:post, topic: t)
    p3 = Fabricate(:post, topic: t, user: p2.user)
    p4 = Fabricate(:post, topic: t)
    p5 = Fabricate(:post, topic: t)

    t.update_columns(featured_user1_id: 66,
                     featured_user2_id: 70,
                     featured_user3_id: 12,
                     featured_user4_id: 7,
                     last_post_user_id: p5.user_id)

    TopicFeaturedUsers.ensure_consistency!
    t.reload

    expect(t.featured_user1_id).to eq(p2.user_id)
    expect(t.featured_user2_id).to eq(p4.user_id)
    expect(t.featured_user3_id).to eq(nil)
    expect(t.featured_user4_id).to eq(nil)

    # after removing a post
    p2.update_column(:deleted_at, Time.now)
    p3.update_column(:hidden, true)

    TopicFeaturedUsers.ensure_consistency!
    t.reload

    expect(t.featured_user1_id).to eq(p4.user_id)
    expect(t.featured_user2_id).to eq(nil)
    expect(t.featured_user3_id).to eq(nil)
    expect(t.featured_user4_id).to eq(nil)
  end
end
