# frozen_string_literal: true

class BadgeGroupingSerializer < ApplicationSerializer
  root 'basge_grouping'
  attributes :id, :name, :description, :position, :system

  def system
    object.system?
  end
end
