require 'rails_helper'
require_dependency 'jobs/base'
require_dependency 'jobs/regular/process_post'

describe Jobs::NotifyMovedPosts do

  it "raises an error without post_ids" do
    expect { Jobs::NotifyMovedPosts.new.execute(moved_by_id: 1234) }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error without moved_by_id" do
    expect { Jobs::NotifyMovedPosts.new.execute(post_ids: [1, 2, 3]) }.to raise_error(Discourse::InvalidParameters)
  end

  context 'with post ids' do
    let!(:p1) { Fabricate(:post) }
    let!(:p2) { Fabricate(:post, user: Fabricate(:evil_trout), topic: p1.topic) }
    let!(:p3) { Fabricate(:post, user: p1.user, topic: p1.topic) }
    let(:admin) { Fabricate(:admin) }

    let(:moved_post_notifications) { Notification.where(notification_type: Notification.types[:moved_post]) }

    it "should create two notifications" do
      expect { Jobs::NotifyMovedPosts.new.execute(post_ids: [p1.id, p2.id, p3.id], moved_by_id: admin.id) }.to change(moved_post_notifications, :count).by(2)
    end

    context 'when moved by one of the posters' do
      it "create one notifications, because the poster is the mover" do
        expect { Jobs::NotifyMovedPosts.new.execute(post_ids: [p1.id, p2.id, p3.id], moved_by_id: p1.user_id) }.to change(moved_post_notifications, :count).by(1)
      end
    end

  end

end
