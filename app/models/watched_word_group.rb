# frozen_string_literal: true

class WatchedWordGroup < ActiveRecord::Base
  validates :action, presence: true

  has_many :watched_words, dependent: :destroy

  def self.actions
    WatchedWord.actions
  end

  def create_or_update_members(words, params)
    WatchedWordGroup.transaction do
      self.action_key = params[:action_key] if params[:action_key]
      self.action = params[:action] if params[:action]
      self.save! if self.changed?

      words.each do |word|
        watched_word =
          WatchedWord.create_or_update_word(
            params.merge(word: word, watched_word_group_id: self.id),
          )

        unless watched_word.valid?
          self.errors.merge!(watched_word.errors)

          raise ActiveRecord::Rollback
        end
      end
    end
  end

  def action_key=(arg)
    self.action = WatchedWordGroup.actions[arg.to_sym]
  end

  def action_log_details
    action_key = WatchedWord.actions.key(self.action)
    "#{action_key} → #{watched_words.pluck(:word).join(", ")}"
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
