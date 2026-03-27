# frozen_string_literal: true

class CategorySetting < ActiveRecord::Base
  # TODO: drop columns require_topic_approval, require_reply_approval in a future migration
  self.ignored_columns += %i[require_topic_approval require_reply_approval]

  belongs_to :category

  enum :topic_posting_review_mode,
       { no_one: 0, everyone: 1, everyone_except: 2, no_one_except: 3 },
       prefix: true
  enum :reply_posting_review_mode,
       { no_one: 0, everyone: 1, everyone_except: 2, no_one_except: 3 },
       prefix: true

  def require_topic_approval=(value)
    self.topic_posting_review_mode =
      ActiveModel::Type::Boolean.new.cast(value) ? :everyone : :no_one
  end

  def require_reply_approval=(value)
    self.reply_posting_review_mode =
      ActiveModel::Type::Boolean.new.cast(value) ? :everyone : :no_one
  end

  def require_topic_approval
    topic_posting_review_mode_everyone?
  end
  alias_method :require_topic_approval?, :require_topic_approval

  def require_reply_approval
    reply_posting_review_mode_everyone?
  end
  alias_method :require_reply_approval?, :require_reply_approval

  GROUP_BASED_MODES = %w[everyone_except no_one_except].freeze

  validates :num_auto_bump_daily,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              allow_nil: true,
            }

  validates :auto_bump_cooldown_days,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              allow_nil: true,
            }
end

# == Schema Information
#
# Table name: category_settings
#
#  id                        :bigint           not null, primary key
#  auto_bump_cooldown_days   :integer          default(1)
#  num_auto_bump_daily       :integer          default(0)
#  reply_posting_review_mode :integer          default("no_one"), not null
#  topic_posting_review_mode :integer          default("no_one"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  category_id               :bigint           not null
#
# Indexes
#
#  index_category_settings_on_category_id  (category_id) UNIQUE
#
