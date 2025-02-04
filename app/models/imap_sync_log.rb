# frozen_string_literal: true

class ImapSyncLog < ActiveRecord::Base
  RETAIN_LOGS_DAYS = 5

  belongs_to :group

  def self.levels
    @levels ||= Enum.new(:debug, :info, :warn, :error)
  end

  def self.log(message, level, group_id = nil, db = true)
    now = Time.now.strftime("%Y-%m-%d %H:%M:%S.%L")

    new_log = (create(message: message, level: ImapSyncLog.levels[level], group_id: group_id) if db)

    if ENV["DEBUG_IMAP"]
      Rails.logger.send(
        :warn,
        "#{level[0].upcase}, [#{now}] [IMAP] (group_id #{group_id}) #{message}",
      )
    else
      Rails.logger.send(
        level,
        "#{level[0].upcase}, [#{now}] [IMAP] (group_id #{group_id}) #{message}",
      )
    end

    new_log
  end

  def self.debug(message, group_or_id, db: true)
    group_id = group_or_id.is_a?(Integer) ? group_or_id : group_or_id.id
    log(message, :debug, group_id, db)
  end

  def self.info(message, group_or_id)
    group_id = group_or_id.is_a?(Integer) ? group_or_id : group_or_id.id
    log(message, :info, group_id)
  end

  def self.warn(message, group_or_id)
    group_id = group_or_id.is_a?(Integer) ? group_or_id : group_or_id.id
    log(message, :warn, group_id)
  end

  def self.error(message, group_or_id)
    group_id = group_or_id.is_a?(Integer) ? group_or_id : group_or_id.id
    log(message, :error, group_id)
  end
end

# == Schema Information
#
# Table name: imap_sync_logs
#
#  id         :bigint           not null, primary key
#  level      :integer          not null
#  message    :string           not null
#  group_id   :bigint
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_imap_sync_logs_on_group_id  (group_id)
#  index_imap_sync_logs_on_level     (level)
#
