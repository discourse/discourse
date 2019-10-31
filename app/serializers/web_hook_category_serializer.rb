# frozen_string_literal: true

class WebHookCategorySerializer < CategorySerializer
  root 'web_hook_category'

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
