# frozen_string_literal: true

class SilencedAssignment < ActiveRecord::Base
  belongs_to :assignment
end

# == Schema Information
#
# Table name: silenced_assignments
#
#  id            :bigint           not null, primary key
#  assignment_id :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_silenced_assignments_on_assignment_id  (assignment_id) UNIQUE
#
