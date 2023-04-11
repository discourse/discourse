# frozen_string_literal: true

class VoiceCredit < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates_presence_of :user, :topic, :category, :credits_allocated
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
