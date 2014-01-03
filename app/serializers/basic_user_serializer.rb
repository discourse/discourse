class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :avatar_template

  def filter(keys)
    keys -= [ :username ] unless SiteSetting.enable_names?
    keys
  end
end
