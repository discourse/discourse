class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :avatar_template

  def include_name?
    SiteSetting.enable_names?
  end
end
