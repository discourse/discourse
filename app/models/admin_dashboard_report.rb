# frozen_string_literal: true

class AdminDashboardReport < ActiveRecord::Base
  VISIBLE_CAP = 10

  validates :source, presence: true
  validates :identifier, presence: true
  validates :identifier, uniqueness: { scope: :source }

  before_validation :assign_default_position, on: :create

  private

  def assign_default_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end
end

# == Schema Information
#
# Table name: admin_dashboard_reports
#
#  id         :bigint           not null, primary key
#  identifier :string           not null
#  position   :integer          not null
#  source     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_admin_dashboard_reports_on_position               (position)
#  index_admin_dashboard_reports_on_source_and_identifier  (source,identifier) UNIQUE
#
