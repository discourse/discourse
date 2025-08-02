# frozen_string_literal: true

class UserRequiredFieldsVersion < ActiveRecord::Base
  def self.current = maximum(:id) || 0
end

# == Schema Information
#
# Table name: user_required_fields_versions
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
