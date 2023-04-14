# frozen_string_literal: true

class VoiceCredit < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates_presence_of :user_id, :topic_id, :category_id, :credits_allocated

  ## technically the limitation is 100 between all the votes per category. But still one allocation can go over 100
  validates :credits_allocated,
            numericality: {
              only_integer: true,
              less_than_or_equal_to: 100,
              greater_than_or_equal_to: 0,
            }

  def vote_value
    Math.sqrt(self.credits_allocated)
  end
end

# == Schema Information
#
# Table name: voice_credits
#
#  id                :bigint           not null, primary key
#  user_id           :integer          not null
#  topic_id          :integer          not null
#  category_id       :integer          not null
#  credits_allocated :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_voice_credits_on_user_id_and_topic_id_and_category_id  (user_id,topic_id,category_id) UNIQUE
#
