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

  def update_posting_review_mode!(post_type, mode, group_ids: [])
    mode = mode.to_s

    if %w[everyone_except no_one_except].include?(mode)
      raise ArgumentError, "group_ids must be provided for #{mode} mode" if group_ids.blank?
    elsif group_ids.present?
      raise ArgumentError,
            "group_ids can only be provided for everyone_except or no_one_except modes"
    end

    transaction do
      update!("#{post_type}_posting_review_mode" => mode)

      category.category_posting_review_groups.where(post_type: post_type).delete_all

      if group_ids.present?
        records =
          group_ids.map do |group_id|
            { category_id: category_id, group_id: group_id, post_type: post_type }
          end
        CategoryPostingReviewGroup.insert_all!(records, record_timestamps: true)
      end
    end
  end

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
