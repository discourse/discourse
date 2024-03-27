# frozen_string_literal: true

class AdminNotice < ActiveRecord::Base
  validates :identifier, presence: true

  enum :priority, %i[low high].freeze
  enum :category, %i[problem].freeze

  def message
    I18n.t("dashboard.admin_notice.#{identifier}", **data.symbolize_keys)
  end
end
