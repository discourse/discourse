# frozen_string_literal: true

class PatreonSyncLog < ActiveRecord::Base
end

# == Schema Information
#
# Table name: patreon_sync_logs
#
#  id         :bigint           not null, primary key
#  synced_at  :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_patreon_sync_logs_on_synced_at  (synced_at)
#
