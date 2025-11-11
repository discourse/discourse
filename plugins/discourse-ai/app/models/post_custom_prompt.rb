# frozen_string_literal: true

class PostCustomPrompt < ActiveRecord::Base
  belongs_to :post
end

class ::Post
  has_one :post_custom_prompt, dependent: :destroy
end

# == Schema Information
#
# Table name: post_custom_prompts
#
#  id            :bigint           not null, primary key
#  post_id       :integer          not null
#  custom_prompt :json             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_post_custom_prompts_on_post_id  (post_id) UNIQUE
#
