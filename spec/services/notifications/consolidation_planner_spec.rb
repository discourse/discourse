# frozen_string_literal: true

require 'rails_helper'

describe Notifications::ConsolidationPlanner do
  describe '#consolidate_or_save!' do
    let(:threshold) { 1 }
    fab!(:user) { Fabricate(:user) }
    let(:like_user) { 'user1' }

    before { SiteSetting.notification_consolidation_threshold = threshold }

    it "does nothing it haven't passed the consolidation threshold yet" do
      notification = build_notification(:liked, { display_username: like_user })

      saved_like = subject.consolidate_or_save!(notification)

      expect(saved_like.id).to be_present
      expect(saved_like.notification_type).to eq(Notification.types[:liked])
    end

    it 'consolidates multiple notifications into a new one' do
      first_notification = Fabricate(:notification, user: user, notification_type: Notification.types[:liked], data: { display_username: like_user }.to_json)
      notification = build_notification(:liked, { display_username: like_user })

      consolidated_like = subject.consolidate_or_save!(notification)

      expect(consolidated_like.id).not_to eq(first_notification.id)
      expect(consolidated_like.notification_type).to eq(Notification.types[:liked_consolidated])
      data = JSON.parse(consolidated_like.data)
      expect(data['count']).to eq(threshold + 1)
    end

    it 'updates the notification if we already consolidated it' do
      count = 5
      Fabricate(:notification,
        user: user, notification_type: Notification.types[:liked_consolidated],
        data: { count: count, display_username: like_user }.to_json
      )
      notification = build_notification(:liked, { display_username: like_user })

      updated = subject.consolidate_or_save!(notification)

      expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
      data = JSON.parse(updated.data)
      expect(data['count']).to eq(count + 1)
    end
  end

  def build_notification(type_sym, data)
    Fabricate.build(:notification, user: user, notification_type: Notification.types[type_sym], data: data.to_json)
  end

  def plan_for(notification)
    subject.plan_for(notification)
  end
end
