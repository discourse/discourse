require 'rails_helper'

RSpec.describe Jobs::CleanUpPostReplyKeys do
  it 'removes old post_reply_keys' do
    freeze_time

    reply_key1 = Fabricate(:post_reply_key, created_at: 1.day.ago)
    reply_key2 = Fabricate(:post_reply_key, created_at: 2.days.ago)
    Fabricate(:post_reply_key, created_at: 3.days.ago)

    SiteSetting.disallow_reply_by_email_after_days = 0

    expect { Jobs::CleanUpPostReplyKeys.new.execute({}) }
      .to change { PostReplyKey.count }.by(0)

    SiteSetting.disallow_reply_by_email_after_days = 2

    expect { Jobs::CleanUpPostReplyKeys.new.execute({}) }
      .to change { PostReplyKey.count }.by(-1)

    expect(PostReplyKey.all).to contain_exactly(
      reply_key1, reply_key2
    )
  end
end
