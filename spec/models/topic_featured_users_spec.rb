require 'rails_helper'

describe TopicFeaturedUsers do
  it 'ensures consistenct' do

    t = Fabricate(:topic)
    Fabricate(:post, topic_id: t.id, user_id: t.user_id)
    p2 = Fabricate(:post, topic_id: t.id)
    Fabricate(:post, topic_id: t.id, user_id: p2.user_id)
    p4 = Fabricate(:post, topic_id: t.id)
    p5 = Fabricate(:post, topic_id: t.id)

    t.update_columns(featured_user1_id: 66,
                     featured_user2_id: 70,
                     featured_user3_id: 12,
                     featured_user4_id: 7,
                     last_post_user_id: p5.user_id
                    )

    TopicFeaturedUsers.ensure_consistency!

    t.reload

    expect(t.featured_user1_id).to eq(p2.user_id)
    expect(t.featured_user2_id).to eq(p4.user_id)
    expect(t.featured_user3_id).to eq(nil)
    expect(t.featured_user4_id).to eq(nil)


  end
end
