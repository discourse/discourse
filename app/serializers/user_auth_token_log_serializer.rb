class UserAuthTokenLogSerializer < ApplicationSerializer
  include UserAuthTokensMixin

  attributes :action

  def action
    case object.action
    when 'generate'
      I18n.t('log_in')
    when 'destroy'
      I18n.t('unsubscribe.log_out')
    else
      I18n.t('staff_action_logs.unknown')
    end
  end
end
