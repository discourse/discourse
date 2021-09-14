# frozen_string_literal: true

require 'rails_helper'

describe ::Jobs::DashboardStats do
  let(:group_message) { GroupMessage.new(Group[:admins].name, :dashboard_problems, limit_once_per: 7.days.to_i) }

  def clear_recently_sent!
    Discourse.redis.del(group_message.sent_recently_key)
  end

  before do
    clear_recently_sent!
  end

  it 'creates group message when problems are persistent for 2 days' do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, Time.zone.now.to_s)
    expect { described_class.new.execute({}) }.not_to change { Topic.count }

    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Topic.count }
  end

  it 'does not duplicate messages' do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Topic.count }
    topic = Topic.last
    clear_recently_sent!

    expect { described_class.new.execute({}) }.not_to change { Topic.count }
    expect(topic.reload.deleted_at.present?).to eq(true)
  end

  it 'duplicates message if previous one has replies' do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Topic.count }
    clear_recently_sent!

    _reply_1 = Fabricate(:post, topic: Topic.last)
    expect { described_class.new.execute({}) }.to change { Topic.count }
  end

  it 'duplicates message if previous was 3 months ago' do
    freeze_time 4.months.ago do
      Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
      expect { described_class.new.execute({}) }.to change { Topic.count }
      clear_recently_sent!
    end

    expect { described_class.new.execute({}) }.to change { Topic.count }
  end
end
