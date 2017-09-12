class GroupPostUserSerializer < BasicUserSerializer
  attributes :title, :name

  def include_name?
    SiteSetting.enable_names?
  end
end
