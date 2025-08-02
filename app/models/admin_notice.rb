# frozen_string_literal: true

class AdminNotice < ActiveRecord::Base
  validates :identifier, presence: true

  enum :priority, %i[low high].freeze
  enum :subject, %i[problem].freeze

  def message
    I18n.t(
      "dashboard.#{subject}.#{identifier}",
      **details.symbolize_keys.merge(base_path: Discourse.base_path),
    )
  end
end

# == Schema Information
#
# Table name: admin_notices
#
#  id         :bigint           not null, primary key
#  subject    :integer          not null
#  priority   :integer          not null
#  identifier :string           not null
#  details    :json             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_admin_notices_on_subject     (subject)
#  index_admin_notices_on_identifier  (identifier)
#
