# frozen_string_literal: true

class UserRequiredFieldsVersion < ActiveRecord::Base
  def self.current = maximum(:id) || 0
end
