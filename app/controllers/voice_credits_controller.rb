# frozen_string_literal: true

class VoiceCreditsController < ApplicationController
  requires_login except: [:total_votes_per_topic_for_category]

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
    voice_credits_by_topic_id = voice_credits.index_by(&:topic_id)

    render json: {
             success: true,
             voice_credits_by_topic_id: voice_credits_by_topic_id,
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

    # Square the sum of total votes per topic
    result.each { |topic_id, topic_data| topic_data[:total_votes] = topic_data[:total_votes]**2 }

    render json: { success: true, total_vote_values_per_topic: result }
  end

  def create
    category_id = params["category_id"]
    user_id = current_user.id
    voice_credits_data = params.require("voice_credits_data").values()
    if voice_credits_data.empty?
      render json: { success: false, error: "Credits missing." }, status: :unprocessable_entity
      return
    end
    voice_credits_data.each do |v_c|
      if v_c["topic_id"].nil? || v_c["credits_allocated"].nil?
        render json: {
                 success: false,
                 error: "Missing attributes for voice credit.",
               },
               status: :unprocessable_entity
        return
      end
    end

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
          user_id: user_id,
          topic_id: voice_credit[:topic_id].to_i,
          category_id: category_id.to_i,
        ).update!(credits_allocated: voice_credit[:credits_allocated].to_i)
      end
    end
    render json: { success: true }
  end
end
