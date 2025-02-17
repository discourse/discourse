# frozen_string_literal: true

module Notifications
  class ConsolidationPlan
    def set_precondition(precondition_blk: nil)
      @precondition_blk = precondition_blk

      self
    end

    def set_mutations(set_data_blk: nil)
      @set_data_blk = set_data_blk

      self
    end

    def can_consolidate_data?(_notification)
      raise NotImplementedError
    end

    def consolidate_or_save!(_notification)
      raise NotImplementedError
    end

    protected

    def consolidated_data(notification)
      return notification.data_hash if @set_data_blk.nil?
      @set_data_blk.call(notification)
    end

    def user_notifications(notification, type)
      notification.user.notifications.where(notification_type: type)
    end
  end
end
