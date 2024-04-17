# frozen_string_literal: true

class WatchedWordGroup < ActiveRecord::Base
  validates :action, presence: true

  has_many :watched_words, dependent: :destroy

  def self.create_membership(params)
    words = params.delete(:words)
    action = params[:action] || WatchedWord.actions[params[:action_key].to_sym]
    group = self.new(action: action)

    group.create_or_update_members(words, params) { group.save! }

    group
  end

  def update_membership(params)
    words = params.delete(:words)
    action = params[:action] || WatchedWord.actions[params[:action_key]] || self.action
    removed_members = self.watched_words.where.not(word: words)

    self.create_or_update_members(words, params) do
      self.update!(action: action) if self.action != action
      removed_members.destroy_all
    end

    self
  end

  def create_or_update_members(words, params)
    WatchedWordGroup.transaction do
      yield if block_given?

      words.each do |word|
        watched_word =
          WatchedWord.create_or_update_word(
            params.merge(word: word, watched_word_group_id: self.id),
          )

        unless watched_word.valid?
          # TODO: Properly bubble up error
          self.errors.merge!({ word: watched_word.inspect })
          self.errors.merge!(watched_word.errors)

          raise ActiveRecord::Rollback
        end
      end
    end
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
