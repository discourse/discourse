class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :avatar_template

  def filter(keys)
    keys.delete(:name) unless SiteSetting.enable_names?
    super(keys)
  end
end
