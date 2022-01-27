# frozen_string_literal: true

class WatchedWord < ActiveRecord::Base

  def self.actions
    @actions ||= Enum.new(
      block: 1,
      censor: 2,
      require_approval: 3,
      flag: 4,
      link: 8,
      replace: 5,
      tag: 6,
      silence: 7,
    )
  end

  MAX_WORDS_PER_ACTION = 2000

  before_validation do
    self.word = self.class.normalize_word(self.word)
    if self.action == WatchedWord.actions[:link] && !(self.replacement =~ /^https?:\/\//)
      self.replacement = "#{Discourse.base_url}#{self.replacement&.starts_with?("/") ? "" : "/"}#{self.replacement}"
    end
  end

  validates :word,   presence: true, uniqueness: true, length: { maximum: 100 }
  validates :action, presence: true

  validate :replacement_is_url, if: -> { action == WatchedWord.actions[:link] }

  validates_each :word do |record, attr, val|
    if WatchedWord.where(action: record.action).count >= MAX_WORDS_PER_ACTION
      record.errors.add(:word, :too_many)
    end
  end

  after_save    :clear_cache
  after_destroy :clear_cache

  scope :by_action, -> { order("action ASC, word ASC") }

  def self.normalize_word(w)
    w.strip.squeeze('*')
  end

  def replacement_is_url
    if !(replacement =~ URI::regexp)
      errors.add(:base, :invalid_url)
    end
  end

  def self.create_or_update_word(params)
    new_word = normalize_word(params[:word])
    w = WatchedWord.where("word ILIKE ?", new_word).first || WatchedWord.new(word: new_word)
    w.replacement = params[:replacement] if params[:replacement]
    w.action_key = params[:action_key] if params[:action_key]
    w.action = params[:action] if params[:action]
    w.save
    w
  end

  def self.has_replacement?(action)
    action == :replace || action == :tag || action == :link
  end

  def action_key=(arg)
    self.action = self.class.actions[arg.to_sym]
  end

  def action_log_details
    if replacement.present?
      "#{word} → #{replacement}"
    else
      word
    end
  end

  def clear_cache
    WordWatcher.clear_cache!
  end
end

# == Schema Information
#
# Table name: watched_words
#
#  id          :integer          not null, primary key
#  word        :string           not null
#  action      :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  replacement :string
#
# Indexes
#
#  index_watched_words_on_action_and_word  (action,word) UNIQUE
#
