class SiteSerializer < ApplicationSerializer

  attributes :default_archetype, :notification_types
  has_many :categories, embed: :objects
  has_many :post_action_types, embed: :objects
  has_many :trust_levels, embed: :objects
  has_many :archetypes, embed: :objects, serializer: ArchetypeSerializer

  def default_archetype
    Archetype.default
  end

end
