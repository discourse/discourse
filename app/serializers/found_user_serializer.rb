# frozen_string_literal: true

class FoundUserSerializer < ApplicationSerializer
  attributes :id, :username, :name, :avatar_template, :status

  def include_name?
    SiteSetting.enable_names?
  end

  def include_status?
    @options[:include_status] && SiteSetting.enable_user_status && object.has_status?
  end

  def status
    UserStatusSerializer.new(object.user_status, root: false)
  end
end
