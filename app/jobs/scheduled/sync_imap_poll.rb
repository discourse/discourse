# frozen_string_literal: true

require 'net/imap'
require_dependency 'imap/sync'

module Jobs
  class SyncImapPoll < ::Jobs::Scheduled
    every SiteSetting.imap_polling_period_mins.minutes
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.enable_imap

      if args[:group_id].blank?
        Group.where.not(imap_mailbox_name: '').pluck(:id).each do |group_id|
          ::Jobs.enqueue(:sync_imap_poll, group_id: group_id)
        end
      else
        group = Group.find_by(id: args[:group_id])
        return if !group || group.imap_mailbox_name.blank?

        DistributedMutex.synchronize("imap_poll_#{group.id}") do
          imap_sync = Imap::Sync.for_group(group)

          begin
            imap_sync.process
          rescue Net::IMAP::Error => e
            Rails.logger.warn("[IMAP] Could not connect to IMAP for group #{group.name}: #{e.message}")
          ensure
            imap_sync.disconnect!
          end
        end
      end
    end
  end
end
