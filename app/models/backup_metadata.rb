# frozen_string_literal: true

class BackupMetadata < ActiveRecord::Base
  LAST_RESTORE_DATE = "last_restore_date"

  def self.value_for(name)
    where(name: name).pick(:value).presence
  end

  def self.last_restore_date
    value = value_for(LAST_RESTORE_DATE)
    value.present? ? Time.zone.parse(value) : nil
  end

  def self.update_last_restore_date(time = Time.zone.now)
    BackupMetadata.where(name: LAST_RESTORE_DATE).delete_all
    BackupMetadata.create!(name: LAST_RESTORE_DATE, value: time.iso8601)
  end
end

# == Schema Information
#
# Table name: backup_metadata
#
#  id    :bigint           not null, primary key
#  name  :string           not null
#  value :string
#
