# frozen_string_literal: true

module Voice
  class RoomHashtagDataSource
    def self.enabled?
      SiteSetting.voice_enabled
    end

    def self.icon
      "microphone-lines"
    end

    def self.type
      "room"
    end

    def self.room_to_hashtag_item(room)
      HashtagAutocompleteService::HashtagItem.new.tap do |item|
        item.text = room.name
        item.description = room.description
        item.slug = room.slug
        item.icon = room.stage? ? "podcast" : icon
        item.style_type = "icon"
        item.relative_url = "#{Discourse.base_path}/voice/r/#{room.slug}"
        item.type = type
        item.id = room.id
      end
    end

    def self.find_by_ids(guardian, ids)
      visible_rooms(guardian, Voice::Room.where(id: ids)).map { |room| room_to_hashtag_item(room) }
    end

    def self.lookup(guardian, slugs)
      return [] if slugs.blank?

      visible_rooms(
        guardian,
        Voice::Room.where("LOWER(slug) IN (?)", slugs.map(&:downcase)),
      ).map { |room| room_to_hashtag_item(room) }
    end

    def self.search(
      guardian,
      term,
      limit,
      condition = HashtagAutocompleteService.search_conditions[:contains]
    )
      escaped_term = ActiveRecord::Base.sanitize_sql_like(term)
      pattern =
        if condition == HashtagAutocompleteService.search_conditions[:starts_with]
          "#{escaped_term}%"
        else
          "%#{escaped_term}%"
        end

      visible_rooms(
        guardian,
        Voice::Room.where("slug ILIKE :pattern OR name ILIKE :pattern", pattern: pattern),
      ).take(limit).map { |room| room_to_hashtag_item(room) }
    end

    def self.search_sort(search_results, _term)
      search_results.sort_by { |result| result.text.downcase }
    end

    def self.search_without_term(guardian, limit)
      visible_rooms(guardian, Voice::Room.all).take(limit).map { |room| room_to_hashtag_item(room) }
    end

    # Visibility is a per-room Guardian question (membership, public flag,
    # manager status), so it can't be expressed as a SQL scope; room counts
    # are small, so filtering loaded records matches RoomsController#index.
    def self.visible_rooms(guardian, scope)
      return [] unless guardian.can_access_voice? || guardian.voice_public_access?

      scope
        .persistent
        .includes(:room_memberships)
        .order(:name)
        .select { |room| guardian.can_see_voice_room?(room) }
    end
    private_class_method :visible_rooms
  end
end
