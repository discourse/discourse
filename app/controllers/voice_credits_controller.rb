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

    discounted_totals = totals

    result = {}
    discounted_result = {}

    ### get Totals with correlation discount
    unique_users = User.all
    unique_groups =
      UserFieldOption.all.map { |x| "user_field_#{x.user_field_id}_#{x.value}".gsub(/\s+/, "_") }
    unique_groups << "no_group"

    unique_topics = Topic.where(category_id: category_id)
    custom_fields = UserCustomField.all

    ## max number of user options
    max_user_options = UserField.count

    user_groups =
      custom_fields
        .group_by(&:user_id)
        .map do |user_id, fields|
          formatted_fields = fields.map { |x| "#{x.name}_#{x.value}" }

          formatted_fields << "no_group" if formatted_fields.empty?

          { user_id: user_id, groups: formatted_fields }
        end

    user_votes = VoiceCredit.where("credits_allocated > 0 AND category_id = ?", category_id)

    processed_groups, topic_contributions =
      ClusterMatchQvHelper.process_data(
        unique_users,
        unique_groups,
        unique_topics,
        user_groups,
        user_votes,
      )

    discounted_totals.each do |ct|
      topic_id = ct[:topic_id]
      vote_value = topic_contributions[topic_id]

      if vote_value.nil?
        discounted_result[topic_id] = { topic_id: topic_id, total_votes: 0 }
      else
        puts "topic_id: #{topic_id}"
        value_score = ClusterMatchQvHelper.cluster_match(processed_groups, vote_value)
        discounted_result[topic_id] = { topic_id: topic_id, total_votes: value_score }
      end
    end
    # topic_contributions example
    # {3=>[6, 0, 0, 0, 0, 0], 29=>[13, 0, 0, 0, 0, 0], 34=>[10, 0, 1, 0, 0, 0], 44=>[17, 0, 0, 0, 0, 0], 39=>[49, 0, 0, 0, 0, 0]}

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

    ## OLD
    # results
    #     {16=>{:topic_id=>16, :total_votes=>0.0},
    #  41=>{:topic_id=>41, :total_votes=>0.0},
    #  3=>{:topic_id=>3, :total_votes=>5.999999999999999}, ####
    #  29=>{:topic_id=>29, :total_votes=>12.999999999999998}, ###
    #  33=>{:topic_id=>33, :total_votes=>0.0},
    #  34=>{:topic_id=>34, :total_votes=>17.324555320336763}, ###
    #  36=>{:topic_id=>36, :total_votes=>0.0},
    #  9=>{:topic_id=>9, :total_votes=>0.0},
    #  10=>{:topic_id=>10, :total_votes=>0.0},
    #  11=>{:topic_id=>11, :total_votes=>0.0},
    #  32=>{:topic_id=>32, :total_votes=>0.0},
    #  12=>{:topic_id=>12, :total_votes=>0.0},
    #  13=>{:topic_id=>13, :total_votes=>0.0},
    #  15=>{:topic_id=>15, :total_votes=>0.0},
    #  17=>{:topic_id=>17, :total_votes=>0.0},
    #  18=>{:topic_id=>18, :total_votes=>0.0},
    #  19=>{:topic_id=>19, :total_votes=>0.0},
    #  44=>{:topic_id=>44, :total_votes=>17.0}, ###
    #  39=>{:topic_id=>39, :total_votes=>49.0}, ####
    #  31=>{:topic_id=>31, :total_votes=>0.0},
    #  40=>{:topic_id=>40, :total_votes=>0.0},
    #  20=>{:topic_id=>20, :total_votes=>0.0},
    #  21=>{:topic_id=>21, :total_votes=>0.0},
    #  22=>{:topic_id=>22, :total_votes=>0.0},
    #  23=>{:topic_id=>23, :total_votes=>0.0},
    #  24=>{:topic_id=>24, :total_votes=>0.0},
    #  25=>{:topic_id=>25, :total_votes=>0.0},
    #  26=>{:topic_id=>26, :total_votes=>0.0},
    #  27=>{:topic_id=>27, :total_votes=>0.0},
    render json: {
             success: true,
             total_vote_values_per_topic: result,
             discounted_total_vote_values_per_topic: discounted_result,
           }
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
