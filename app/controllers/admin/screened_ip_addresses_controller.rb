class Admin::ScreenedIpAddressesController < Admin::AdminController

  def index
    screened_emails = ScreenedIpAddress.limit(200).order('last_match_at desc').to_a
    render_serialized(screened_emails, ScreenedIpAddressSerializer)
  end

end
