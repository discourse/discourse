# frozen_string_literal: true

class CategorySetting < ActiveRecord::Base
  belongs_to :category

  # TODO: drop columns require_topic_approval, require_reply_approval in a future migration
  self.ignored_columns += %i[require_topic_approval require_reply_approval]

  enum :topic_approval_type,
       { none: 0, all: 1, except_groups: 2, only_groups: 3 }.freeze,
       scopes: false

  enum :reply_approval_type,
       { none: 0, all: 1, except_groups: 2, only_groups: 3 }.freeze,
       scopes: false,
       instance_methods: false

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
#  id                      :bigint           not null, primary key
#  auto_bump_cooldown_days :integer          default(1)
#  num_auto_bump_daily     :integer          default(0)
#  reply_approval_type     :integer          default("none"), not null
#  topic_approval_type     :integer          default("none"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :bigint           not null
#
# Indexes
#
#  index_category_settings_on_category_id  (category_id) UNIQUE
#
