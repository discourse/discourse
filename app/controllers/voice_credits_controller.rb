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

  # Returns the total vote value per topic for a given category
  # The vote value is the translation of voice_credits (SQRT(voice_credits)
  def total_votes_per_topic_for_category
    category_id = params[:category_id]
    totals =
      VoiceCredit
        .where(category_id: category_id)
        .map { |record| { topic_id: record.topic_id, vote_value: record.vote_value } }

    result = {}
    totals.each do |ct|
      topic_id = ct[:topic_id]
      vote_value = ct[:vote_value]
      if result[topic_id].nil?
        result[topic_id] = { topic_id: topic_id, total_votes: vote_value }
      else
        result[topic_id][:total_votes] += vote_value
      end
    end

    render json: { total_vote_values_per_topic: result }
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
