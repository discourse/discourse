# frozen_string_literal: true

class Admin::OnboardingEventsController < Admin::AdminController
  STEPS = UserHistory::ADMIN_ONBOARDING_STEPS

  def create
    logger = StaffActionLogger.new(current_user)

    case params.require(:event)
    when "step_completed"
      step = params.require(:step)
      raise Discourse::InvalidParameters.new(:step) if !STEPS.include?(step)
      topic_option = params[:topic_option]
      if topic_option.present? &&
           (
             step != "start_posting" ||
               !UserHistory::ADMIN_ONBOARDING_TOPIC_OPTIONS.include?(topic_option)
           )
        raise Discourse::InvalidParameters.new(:topic_option)
      end
      logger.log_admin_onboarding_step_completed(step, topic_option: topic_option.presence)
    when "completed"
      logger.log_admin_onboarding_completed
    when "dismissed"
      logger.log_admin_onboarding_dismissed
    else
      raise Discourse::InvalidParameters.new(:event)
    end

    head :no_content
  end
end
