# frozen_string_literal: true

class VoiceCreditsController < ApplicationController
  def update
    voice_credits_data = params.require(:voice_credits)

    VoiceCredit.transaction do
      voice_credits_data.each do |voice_credit|
        VoiceCredit.find_or_initialize_by(
          user_id: current_user.id,
          topic_id: voice_credit[:topic_id],
          category_id: voice_credit[:category_id],
        ).update!(credits_allocated: voice_credit[:credits_allocated])
      end
    end

    render json: { success: true }
  end
end
