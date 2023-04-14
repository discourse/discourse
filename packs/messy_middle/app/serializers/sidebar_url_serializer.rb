# frozen_string_literal: true

class SidebarUrlSerializer < ApplicationSerializer
  attributes :id, :name, :value, :icon, :external

  def external
    object.external? || object.full_reload?
  end
end
