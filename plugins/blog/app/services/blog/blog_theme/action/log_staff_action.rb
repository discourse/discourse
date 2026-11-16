# frozen_string_literal: true

class Blog::BlogTheme::Action::LogStaffAction < Service::ActionBase
  option :actor
  option :theme
  option :event

  def call
    StaffActionLogger.new(actor).log_custom(
      "blog_theme_#{event}",
      theme_id: theme["id"],
      name: theme["name"],
      revision: theme["revision"],
    )
  end
end
