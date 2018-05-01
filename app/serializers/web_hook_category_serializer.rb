class WebHookCategorySerializer < CategorySerializer

  %i{
    can_edit
    notification_level
    available_groups
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end

end
