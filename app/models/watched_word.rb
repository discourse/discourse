# frozen_string_literal: true

class WatchedWord < ActiveRecord::Base
  MAX_WORDS_PER_ACTION = 2000

  before_validation do
    self.word = WatchedWord.normalize_word(self.word)
    self.replacement = WatchedWord.normalize_word(self.replacement) if self.replacement.present?
  end

  before_validation do
    if self.action == WatchedWord.actions[:link] && self.replacement !~ %r{\Ahttps?://}
      self.replacement =
        "#{Discourse.base_url}#{self.replacement&.starts_with?("/") ? "" : "/"}#{self.replacement}"
    end
  end

  validates :word, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :replacement, length: { maximum: 100 }
  validates :action, presence: true
  validate :replacement_is_url, if: -> { action == WatchedWord.actions[:link] }
  validate :replacement_is_tag_list, if: -> { action == WatchedWord.actions[:tag] }
  validate :replacement_is_html, if: -> { replacement.present? && html? }

  validates_each :word do |record, attr, val|
    if WatchedWord.where(action: record.action).count >= MAX_WORDS_PER_ACTION
      record.errors.add(:word, :too_many)
    end
  end

  after_save -> { WordWatcher.clear_cache! }
  after_destroy -> { WordWatcher.clear_cache! }

  scope :for,
        ->(word:) do
          where(
            "(word ILIKE :word AND case_sensitive = 'f') OR (word LIKE :word AND case_sensitive = 't')",
            word: word,
          )
        end

  def self.actions
    @actions ||=
      Enum.new(
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

  belongs_to :watched_word_group

  scope :for,
        ->(word:) do
          where(
            "(word ILIKE :word AND case_sensitive = 'f') OR (word LIKE :word AND case_sensitive = 't')",
            word: word,
          )
        end

  def self.create_or_update_word(params)
    word = normalize_word(params[:word])
    word = self.for(word: word).first_or_initialize(word: word)
    word.replacement = params[:replacement] if params[:replacement]
    word.action_key = params[:action_key] if params[:action_key]
    word.action = params[:action] if params[:action]
    word.case_sensitive = params[:case_sensitive] if !params[:case_sensitive].nil?
    word.html = params[:html] if params[:html]
    word.watched_word_group_id = params[:watched_word_group_id]
    word.save
    word
  end

  def self.has_replacement?(action)
    action == :replace || action == :tag || action == :link
  end

  def action_key=(arg)
    self.action = WatchedWord.actions[arg.to_sym]
  end

  def action_log_details
    replacement.present? ? "#{word} → #{replacement}" : word
  end

  private

  def self.normalize_word(word)
    # When a regular expression is converted to a string, it is wrapped with
    # '(?-mix:' and ')'
    word = word[7..-2] if word.start_with?("(?-mix:")

    word.strip.squeeze("*")
  end

  def replacement_is_url
    errors.add(:base, :invalid_url) if replacement !~ URI.regexp
  end

  def replacement_is_tag_list
    tag_list = replacement&.split(",")
    tags = Tag.where(name: tag_list)
    if tag_list.blank? || tags.empty? || tag_list.size != tags.size
      errors.add(:base, :invalid_tag_list)
    end
  end

  def replacement_is_html
    errors.add(:base, :invalid_html) if action != WatchedWord.actions[:replace]
  end
end

# == Schema Information
#
# Table name: watched_words
#
#  id                    :integer          not null, primary key
#  word                  :string           not null
#  action                :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  replacement           :string
#  case_sensitive        :boolean          default(FALSE), not null
#  watched_word_group_id :bigint
#  html                  :boolean          default(FALSE), not null
#
# Indexes
#
#  index_watched_words_on_action_and_word        (action,word) UNIQUE
#  index_watched_words_on_watched_word_group_id  (watched_word_group_id)
#
