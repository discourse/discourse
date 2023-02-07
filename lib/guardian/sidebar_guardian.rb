# frozen_string_literal: true

module SidebarGuardian
  def can_edit_sidebar_section?(sidebar_section)
    is_my_own?(sidebar_section)
  end

  def can_delete_sidebar_section?(sidebar_section)
    is_my_own?(sidebar_section)
  end
end
