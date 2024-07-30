# frozen_string_literal: true

class WatchedWordGroup < ActiveRecord::Base
  validates :action, presence: true
  validate :watched_words_validation

  has_many :watched_words, dependent: :destroy

  def watched_words_validation
    watched_words.each { |word| errors.merge!(word.errors) }
    errors.add(:watched_words, :empty) if watched_words.empty?
  end

  def create_or_update_members(words, params)
    WatchedWordGroup.transaction do
      self.action = WatchedWord.actions[params[:action_key].to_sym]

      words.each do |word|
        watched_word = WatchedWord.create_or_update_word(params.merge(word: word))
        self.watched_words << watched_word
      end

      self.save!
    end
  end

  def action_log_details
    "#{WatchedWord.actions.key(self.action)} → #{watched_words.pluck(:word).join(", ")}"
  end
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
