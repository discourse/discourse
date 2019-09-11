# frozen_string_literal: true

NotificationType.old_types.each do |name, id|
  NotificationType.seed(:name) do |notification_type|
    notification_type.name = name
    notification_type.id = id
  end
end

NotificationType.new_types.each do |name|
  NotificationType.seed(:name) do |notification_type|
    notification_type.name = name
  end
end
