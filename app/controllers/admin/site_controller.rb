# frozen_string_literal: true

class Admin::SiteController < Admin::AdminController
  allow_in_readonly_mode :archive

  def archive
    enable = params.fetch(:enable).to_s == "true"

    if enable
      Discourse.enable_readonly_mode(Discourse::ARCHIVE_MODE_KEY)
    else
      Discourse.disable_readonly_mode(Discourse::ARCHIVE_MODE_KEY)
    end

    StaffActionLogger.new(current_user).log_change_archive_mode(enable)

    render body: nil
  end
end
