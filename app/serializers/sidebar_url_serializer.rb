# frozen_string_literal: true

class SidebarUrlSerializer < ApplicationSerializer
  attributes :id, :name, :value, :icon, :external, :full_reload, :segment

  def external
    object.external?
  end

  def full_reload
    object.full_reload?
  end
end
