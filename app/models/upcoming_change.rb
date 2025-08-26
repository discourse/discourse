# frozen_string_literal: true

class UpcomingChange < ActiveRecord::Base
end

# == Schema Information
#
# Table name: upcoming_changes
#
#  id                :bigint           not null, primary key
#  description       :string           not null
#  enabled           :boolean          default(FALSE), not null
#  identifier        :string           not null
#  plugin_identifier :string
#  risk_level        :integer          default(0), not null
#  status            :integer          default(0), not null
#  type              :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  enabled_by_id     :bigint
#  meta_topic_id     :integer
#
# Indexes
#
#  index_upcoming_changes_on_enabled_by_id      (enabled_by_id)
#  index_upcoming_changes_on_identifier         (identifier) UNIQUE
#  index_upcoming_changes_on_plugin_identifier  (plugin_identifier)
#
