# frozen_string_literal: true

##
# If group SMTP or IMAP has been configured, we want to make sure the
# credentials are always valid otherwise emails will not be sending out
# from group inboxes. This check is run as part of scheduled admin
# problem checks, and if any credentials have issues they will show up on
# the admin dashboard as a high priority issue.
class ProblemCheck::GroupEmailCredentials < ProblemCheck
  self.priority = "high"
  self.perform_every = 30.minutes

  def call
    [*smtp_errors, *imap_errors]
  end

  private

  def targets
    [*Group.with_smtp_configured.pluck(:name), *Group.with_imap_configured.pluck(:name)]
  end

  def smtp_errors
    return [] if !SiteSetting.enable_smtp

    Group.with_smtp_configured.find_each.filter_map do |group|
      try_validate(group) do
        EmailSettingsValidator.validate_smtp(
          host: group.smtp_server,
          port: group.smtp_port,
          username: group.email_username,
          password: group.email_password,
        )
      end
    end
  end

  def imap_errors
    return [] if !SiteSetting.enable_imap

    Group.with_imap_configured.find_each.filter_map do |group|
      try_validate(group) do
        EmailSettingsValidator.validate_imap(
          host: group.imap_server,
          port: group.imap_port,
          username: group.email_username,
          password: group.email_password,
        )
      end
    end
  end

  def try_validate(group, &blk)
    begin
      blk.call
      nil
    rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS => err
      message =
        I18n.t(
          "dashboard.problem.group_email_credentials",
          {
            base_path: Discourse.base_path,
            group_name: group.name,
            group_full_name: group.full_name,
            error: EmailSettingsExceptionHandler.friendly_exception_message(err, group.smtp_server),
          },
        )

      Problem.new(
        message,
        priority: "high",
        identifier: "group_email_credentials",
        target: group.id,
        details: {
          group_name: group.name,
          group_full_name: group.full_name,
          error: EmailSettingsExceptionHandler.friendly_exception_message(err, group.smtp_server),
        },
      )
    rescue => err
      Discourse.warn_exception(
        err,
        message:
          "Unexpected error when checking SMTP credentials for group #{group.id} (#{group.name}).",
      )
      nil
    end
  end
end
