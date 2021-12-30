# frozen_string_literal: true

require 'rails_helper'

describe Notifications::ConsolidateNotifications do
  describe '#before_consolidation_callbacks' do
    fab!(:user) { Fabricate(:user) }
    let(:rule) do
      described_class.new(
        from: Notification.types[:liked],
        to: Notification.types[:liked],
        consolidation_window: 10.minutes,
        consolidated_query_blk: Proc.new do |notifications|
          notifications.where("(data::json ->> 'consolidated')::bool")
        end,
        threshold: 1
      ).set_mutations(set_data_blk: Proc.new { |n| n.data_hash.merge(consolidated: true) })
    end

    it 'applies a callback when consolidating a notification' do
      rule.before_consolidation_callbacks(
        before_consolidation_blk: Proc.new do |_, data|
          data[:consolidation_callback_called] = true
        end
      )

      rule.consolidate_or_save!(build_like_notification)
      rule.consolidate_or_save!(build_like_notification)

      consolidated_notification = Notification.where(user: user).last

      expect(consolidated_notification.data_hash[:consolidation_callback_called]).to eq(true)
    end

    it 'applies a callback when updating a consolidated notification' do
      rule.before_consolidation_callbacks(
        before_update_blk: Proc.new do |_, data|
          data[:update_callback_called] = true
        end
      )

      rule.consolidate_or_save!(build_like_notification)
      rule.consolidate_or_save!(build_like_notification)

      consolidated_notification = Notification.where(user: user).last

      expect(consolidated_notification.data_hash[:update_callback_called]).to be_nil

      rule.consolidate_or_save!(build_like_notification)

      consolidated_notification = Notification.where(user: user).last

      expect(consolidated_notification.data_hash[:update_callback_called]).to eq(true)
    end

    def build_like_notification
      Fabricate.build(:notification, user: user, notification_type: Notification.types[:liked], data: {}.to_json)
    end
  end
end
