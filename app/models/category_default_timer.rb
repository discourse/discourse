# frozen_string_literal: true
class CategoryDefaultTimer < BaseTimer
  belongs_to :user
  belongs_to :category, class_name: "Category", foreign_key: :timerable_id
end

# == Schema Information
#
# Table name: topic_timers
#
#  id                 :integer          not null, primary key
#  based_on_last_post :boolean          default(FALSE), not null
#  deleted_at         :datetime
#  duration_minutes   :integer
#  execute_at         :datetime         not null
#  public_type        :boolean          default(TRUE)
#  status_type        :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  category_id        :integer
#  deleted_by_id      :integer
#  topic_id           :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  idx_topic_id_public_type_deleted_at  (topic_id) UNIQUE WHERE ((public_type = true) AND (deleted_at IS NULL))
#  index_topic_timers_on_topic_id       (topic_id) WHERE (deleted_at IS NULL)
#  index_topic_timers_on_user_id        (user_id)
#
