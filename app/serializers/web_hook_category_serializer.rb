class WebHookCategorySerializer < CategorySerializer

  %i{
    can_edit
    notification_level
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end

end
