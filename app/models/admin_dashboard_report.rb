# frozen_string_literal: true

class AdminDashboardReport < ActiveRecord::Base
  VISIBLE_CAP = 10
  MAX_ROWS = 4
  MAX_COLS = 2

  validates :source, presence: true
  validates :identifier, presence: true
  validates :identifier, uniqueness: { scope: :source }
  validates :rows,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: MAX_ROWS,
            }
  validates :cols,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: MAX_COLS,
            }
  validate :source_must_be_registered
  validate :multi_row_cards_must_be_full_width

  before_validation :assign_default_position, on: :create

  private

  def assign_default_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end

  def source_must_be_registered
    return if source.blank?
    return if AdminDashboard::Reports::Registry.provider_for(source)
    errors.add(:source, :invalid)
  end

  def multi_row_cards_must_be_full_width
    return if rows.to_i <= 1 || cols.to_i == MAX_COLS
    errors.add(:cols, :invalid)
  end
end

# == Schema Information
#
# Table name: admin_dashboard_reports
#
#  id         :bigint           not null, primary key
#  cols       :integer          default(1), not null
#  identifier :string           not null
#  position   :integer          not null
#  rows       :integer          default(1), not null
#  source     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_admin_dashboard_reports_on_position               (position)
#  index_admin_dashboard_reports_on_source_and_identifier  (source,identifier) UNIQUE
#
