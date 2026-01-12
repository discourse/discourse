# frozen_string_literal: true

##
# If group SMTP has been configured, we want to make sure the
# credentials are always valid otherwise emails will not be sending out
# from group inboxes. This check is run as part of scheduled admin
# problem checks, and if any credentials have issues they will show up on
# the admin dashboard as a high priority issue.
class ProblemCheck::GroupEmailCredentials < ProblemCheck
  self.priority = "high"
  self.perform_every = 30.minutes
  self.targets = -> { Group.with_smtp_configured.pluck(:name) }

  def call
    if group = Group.with_smtp_configured.find_by(name: target)
      return no_problem if !SiteSetting.enable_smtp

      return(
        try_validate(group) do
          EmailSettingsValidator.validate_smtp(
            host: group.smtp_server,
            port: group.smtp_port,
            username: group.email_username,
            password: group.email_password,
          )
        end
      )
    end

    no_problem
  end

  private

  def translation_data(group)
    { group_name: group.name, group_full_name: group.full_name }
  end

  def try_validate(group, &blk)
    begin
      blk.call
      no_problem
    rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS => err
      error_message =
        EmailSettingsExceptionHandler.friendly_exception_message(err, group.smtp_server)

      problem(group, override_data: { error: error_message })
    rescue => err
      Discourse.warn_exception(
        err,
        message:
          "Unexpected error when checking SMTP credentials for group #{group.id} (#{group.name}).",
      )
      no_problem
    end
  end
end
