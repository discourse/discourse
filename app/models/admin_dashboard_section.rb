# frozen_string_literal: true

class AdminDashboardSection < ActiveRecord::Base
  validates :section_id, presence: true, uniqueness: true
  validates :position, presence: true
  validates :visible, inclusion: { in: [true, false] }
end

# == Schema Information
#
# Table name: admin_dashboard_sections
#
#  id         :bigint           not null, primary key
#  position   :integer          not null
#  visible    :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  section_id :string           not null
#
# Indexes
#
#  index_admin_dashboard_sections_on_section_id  (section_id) UNIQUE
#
