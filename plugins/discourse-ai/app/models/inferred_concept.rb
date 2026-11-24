# frozen_string_literal: true

class InferredConcept < ActiveRecord::Base
  enum :status, { candidate: 0, active: 1, retired: 2 }

  belongs_to :parent, class_name: "InferredConcept", optional: true
  has_many :children, class_name: "InferredConcept", foreign_key: :parent_id, dependent: :nullify

  has_many :inferred_concept_topics, dependent: :delete_all
  has_many :topics, through: :inferred_concept_topics

  has_many :inferred_concept_posts, dependent: :delete_all
  has_many :posts, through: :inferred_concept_posts

  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :description, length: { maximum: 1000 }
  validate :parent_cannot_create_cycle

  before_validation :ensure_slug
  before_validation :normalize_aliases
  after_destroy :delete_embeddings

  scope :by_name_or_alias,
        ->(term) do
          normalized = term.to_s.strip.downcase
          where(
            "lower(name) = :term OR EXISTS (SELECT 1 FROM unnest(aliases) AS alias WHERE lower(alias) = :term)",
            term: normalized,
          ).order(Arel.sql("CASE status WHEN 1 THEN 0 WHEN 0 THEN 1 ELSE 2 END, id ASC"))
        end

  def text_for_embedding
    parts = [name]
    parts << description if description.present?
    parts << "Also known as: #{aliases.join(", ")}" if aliases.present?
    parts.join("\n\n")
  end

  private

  def ensure_slug
    self.slug ||= ""
    return if name.blank?

    if slug.blank? || (will_save_change_to_name? && !will_save_change_to_slug?)
      self.slug = Slug.for(name, "")
      self.slug = "" if slug.blank? || duplicate_slug?
    end
  end

  def duplicate_slug?
    return false if slug.blank?

    scope = InferredConcept.where("lower(slug) = ?", slug.downcase)
    scope = scope.where.not(id: id) if id.present?
    scope.exists?
  end

  def normalize_aliases
    name_downcase = name.to_s.strip.downcase
    seen = Set.new
    seen << name_downcase if name_downcase.present?

    self.aliases =
      Array(aliases).filter_map do |entry|
        cleaned = entry.to_s.strip
        next if cleaned.blank?

        key = cleaned.downcase
        next if seen.include?(key)

        seen << key
        cleaned
      end
  end

  def parent_cannot_create_cycle
    return if parent_id.blank? || id.blank?

    visited = Set[id]
    current_id = parent_id

    while current_id.present?
      if visited.include?(current_id)
        errors.add(:parent_id, :invalid)
        return
      end

      visited << current_id
      current_id = InferredConcept.where(id: current_id).pick(:parent_id)
    end
  end

  def delete_embeddings
    DiscourseAi::Embeddings::Schema.delete_embeddings_for(self)
  end
end

# == Schema Information
#
# Table name: inferred_concepts
#
#  id          :bigint           not null, primary key
#  aliases     :text             default([]), not null, is an Array
#  description :text             default(""), not null
#  name        :string           not null
#  slug        :string           default(""), not null
#  status      :integer          default("active"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :bigint
#
# Indexes
#
#  index_inferred_concepts_on_lower_name  (lower((name)::text))
#  index_inferred_concepts_on_name        (name) UNIQUE
#  index_inferred_concepts_on_parent_id   (parent_id) WHERE (parent_id IS NOT NULL)
#  index_inferred_concepts_on_slug        (slug) UNIQUE WHERE ((slug)::text <> ''::text)
#  index_inferred_concepts_on_status      (status)
#
