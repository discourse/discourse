# frozen_string_literal: true

##
# If group SMTP or IMAP has been configured, we want to make sure the
# credentials are always valid otherwise emails will not be sending out
# from group inboxes. This check is run as part of scheduled AdminDashboardData
# problem checks, and if any credentials have issues they will show up on
# the admin dashboard as a high priority issue.
class GroupEmailCredentialsCheck
  def self.run
    errors = []

    if SiteSetting.enable_smtp
      Group.with_smtp_configured.find_each do |group|
        errors << try_validate(group) do
          EmailSettingsValidator.validate_smtp(
            host: group.smtp_server,
            port: group.smtp_port,
            username: group.email_username,
            password: group.email_password
          )
        end
      end
    end

    if SiteSetting.enable_imap
      Group.with_imap_configured.find_each do |group|
        errors << try_validate(group) do
          EmailSettingsValidator.validate_imap(
            host: group.smtp_server,
            port: group.smtp_port,
            username: group.email_username,
            password: group.email_password
          )
        end
      end
    end

    errors.compact
  end

  def self.try_validate(group, &blk)
    begin
      blk.call
      nil
    rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS => err
      {
        group_id: group.id,
        group_name: group.name,
        group_full_name: group.full_name,
        message: EmailSettingsExceptionHandler.friendly_exception_message(err, group.smtp_server)
      }
    rescue => err
      Discourse.warn_exception(
        err, message: "Unexpected error when checking SMTP credentials for group #{group.id} (#{group.name})."
      )
      nil
    end
  end
end
