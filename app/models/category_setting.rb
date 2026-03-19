# frozen_string_literal: true

class CategorySetting < ActiveRecord::Base
  # TODO: drop columns require_topic_approval, require_reply_approval in a future migration
  self.ignored_columns += %i[require_topic_approval require_reply_approval]

  belongs_to :category

  before_save :sync_posting_review_groups

  def require_topic_approval=(value)
    @require_topic_approval = value
    updated_at_will_change!
  end

  def require_reply_approval=(value)
    @require_reply_approval = value
    updated_at_will_change!
  end

  def require_topic_approval
    goldiload { |ids| CategorySetting.approval_required_map(ids, :topic) }
  end
  alias_method :require_topic_approval?, :require_topic_approval

  def require_reply_approval
    goldiload { |ids| CategorySetting.approval_required_map(ids, :reply) }
  end
  alias_method :require_reply_approval?, :require_reply_approval

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

  def self.approval_required_map(ids, post_type)
    approved_ids =
      where(
        id: ids,
        category_id:
          CategoryPostingReviewGroup.where(
            post_type: post_type,
            permission: :required,
            group_id: Group::AUTO_GROUPS[:everyone],
          ).select(:category_id),
      ).pluck(:id).to_set

    ids.index_with { |id| approved_ids.include?(id) }
  end

  private

  def sync_posting_review_groups
    return if @require_topic_approval.nil? && @require_reply_approval.nil?

    everyone = Group[:everyone]

    { topic: @require_topic_approval, reply: @require_reply_approval }.each do |type, value|
      next if value.nil?

      scope = category.category_posting_review_groups.where(post_type: type)
      if ActiveModel::Type::Boolean.new.cast(value)
        scope.create_or_find_by!(permission: :required, group: everyone)
      else
        scope.where(group: everyone, permission: :required).delete_all
      end
    end

    @require_topic_approval = nil
    @require_reply_approval = nil
  end
end

# == Schema Information
#
# Table name: category_settings
#
#  id                      :bigint           not null, primary key
#  auto_bump_cooldown_days :integer          default(1)
#  num_auto_bump_daily     :integer          default(0)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :bigint           not null
#
# Indexes
#
#  index_category_settings_on_category_id  (category_id) UNIQUE
#
