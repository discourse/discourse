# frozen_string_literal: true
class CategoryDefaultTimer < BaseTimer
  belongs_to :user
  belongs_to :category, foreign_key: :timerable_id
  belongs_to :publishing_category, class_name: "Category", foreign_key: :category_id

  validates :user_id, presence: true
  validates :timerable_id, presence: true
  validates :status_type, uniqueness: { scope: %i[timerable_id deleted_at] }, if: :public_type?
  validates :status_type,
            uniqueness: {
              scope: %i[timerable_id deleted_at user_id],
            },
            if: :private_type?
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
#  type               :string           default("TopicTimer"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  category_id        :integer
#  deleted_by_id      :integer
#  timerable_id       :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  idx_timerable_id_public_type_deleted_at  (timerable_id) UNIQUE WHERE ((public_type = true) AND (deleted_at IS NULL) AND ((type)::text = 'TopicTimer'::text))
#  index_topic_timers_on_timerable_id       (timerable_id) WHERE (deleted_at IS NULL)
#  index_topic_timers_on_user_id            (user_id)
#
