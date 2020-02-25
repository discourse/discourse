# frozen_string_literal: true

class BackupMetadata < ActiveRecord::Base
  LAST_RESTORE_DATE = "last_restore_date"

  def self.value_for(name)
    where(name: name).pluck_first(:value).presence
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
