# frozen_string_literal: true

class VoiceCreditsController < ApplicationController
  def index
    category_id = params.require(:category_id)
    if category_id == "all"
      voice_credits = VoiceCredit.where(user_id: current_user.id).includes(:topic, :category)
    else
      voice_credits =
        VoiceCredit.where(user_id: current_user.id, category_id: category_id).includes(
          :topic,
          :category,
        )
    end

    render json: {
             success: true,
             voice_credits:
               ActiveModel::ArraySerializer.new(
                 voice_credits,
                 each_serializer: VoiceCreditSerializer,
               ),
           }
  end

  def update
    voice_credits_data = params.require(:voice_credits)

    if voice_credits_data.map { |vc| vc[:credits_allocated].to_i }.sum > 100
      render json: {
               success: false,
               error: "Credits allocation exceeded the limit of 100.",
             },
             status: :unprocessable_entity
      return
    end

    VoiceCredit.transaction do
      voice_credits_data.each do |voice_credit|
        VoiceCredit.find_or_initialize_by(
          user_id: current_user.id,
          topic_id: voice_credit[:topic_id],
        ).update!(credits_allocated: voice_credit[:credits_allocated])
      end
    end

    render json: { success: true }
  end
end
