# frozen_string_literal: true

class Admin::OnboardingEventsController < Admin::AdminController
  STEPS = %w[select_theme invite_collaborators start_posting].freeze

  def create
    logger = StaffActionLogger.new(current_user)

    case params.require(:event)
    when "step_completed"
      step = params.require(:step)
      raise Discourse::InvalidParameters.new(:step) if !STEPS.include?(step)
      logger.log_admin_onboarding_step_completed(step)
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
