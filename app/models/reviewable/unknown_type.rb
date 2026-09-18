# frozen_string_literal: true

# Reviewables outlive the code that defines their type whenever a plugin is disabled or
# removed. Their rows are loaded through this class so the generic behaviour they share
# with every other reviewable keeps working, instead of raising `SubclassNotFound`.
#
# They are excluded from the review queue by `Reviewable.list_for`, so no action can be
# performed on them until their type is defined again.
class Reviewable::UnknownType < Reviewable
  self.inheritance_column = nil

  def build_actions(actions, guardian, args)
  end

  # Preserves the source recorded while the type was still defined, so administrators
  # can tell which plugin these belong to.
  def set_type_source
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  dsa_category            :string
#  dsa_subcategory         :string
#  dsa_subcategory_other   :string(500)
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  legal_basis             :string
#  outcome_source          :string
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  restriction_type        :string
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_awaiting_dsa_classification               (status) WHERE ((legal_basis IS NOT NULL) AND (dsa_category IS NULL))
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
