# frozen_string_literal: true

class FoundUserSerializer < ApplicationSerializer
  include UserStatusMixin

  attributes :id, :username, :name, :avatar_template

  def include_name?
    SiteSetting.enable_names?
  end
end
