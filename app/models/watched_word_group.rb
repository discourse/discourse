# frozen_string_literal: true

class WatchedWordGroup < ActiveRecord::Base
  validates :action, presence: true

  has_many :watched_words, dependent: :destroy
end

# == Schema Information
#
# Table name: watched_word_groups
#
#  id         :bigint           not null, primary key
#  action     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
