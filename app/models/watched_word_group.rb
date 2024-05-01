# frozen_string_literal: true

class WatchedWordGroup < ActiveRecord::Base
  validates :action, presence: true

  has_many :watched_words, dependent: :destroy

  def create_or_update_members(words, params)
    WatchedWordGroup.transaction do
      self.action = WatchedWord.actions[params[:action_key].to_sym]
      self.save! if self.changed?

      words.each do |word|
        watched_word =
          WatchedWord.create_or_update_word(
            params.merge(word: word, watched_word_group_id: self.id),
          )

        if !watched_word.valid?
          self.errors.merge!(watched_word.errors)
          raise ActiveRecord::Rollback
        end
      end
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
