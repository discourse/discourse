# frozen_string_literal: true

module ::Lovelace
  class Checklist
    MAX_ITEMS = 50
    LINK_TYPES = %w[custom category topic chat profile notifications account].freeze
    FIELDS = {
      "id" => 100,
      "title" => 120,
      "description" => 1000,
      "url" => 2048,
      "button_text" => 80,
      "link_type" => 20,
    }.freeze
    SETTINGS_PATHS = {
      "profile" => "/my/preferences/profile",
      "notifications" => "/my/preferences/notifications",
      "account" => "/my/preferences/account",
    }.freeze

    def self.read
      PluginStore.get(PLUGIN_NAME, "checklist") || { "items" => [], "revision" => 0 }
    end

    def self.normalize(items)
      unless items.is_a?(Array) && items.size <= MAX_ITEMS
        raise Discourse::InvalidParameters.new(:items)
      end

      normalized =
        items.map do |item|
          raise Discourse::InvalidParameters.new(:items) unless item.is_a?(Hash)
          result =
            FIELDS.to_h do |field, limit|
              value = item[field]
              unless value.is_a?(String) && value.length <= limit
                raise Discourse::InvalidParameters.new(field)
              end
              [field, value.strip]
            end
          %w[id title button_text].each do |field|
            raise Discourse::InvalidParameters.new(field) if result[field].blank?
          end
          type = result["link_type"]
          raise Discourse::InvalidParameters.new(:link_type) if LINK_TYPES.exclude?(type)
          result["url"] = SETTINGS_PATHS[type] || result["url"]
          url = result["url"]
          valid_url = url.match?(%r{\A/(?!/)[^\s\\]*\z}) || url.match?(%r{\Ahttps?://[^\s\\]+\z}i)
          if %w[category topic chat].include?(type)
            prefix = { "category" => "c", "topic" => "t", "chat" => "chat/c" }.fetch(type)
            valid_url &&= url.match?(%r{\A/#{prefix}/[^\s]+\z})
          end
          raise Discourse::InvalidParameters.new(:url) unless valid_url
          result
        end
      if normalized.map { |item| item["id"] }.uniq.size != normalized.size
        raise Discourse::InvalidParameters.new(:id)
      end
      normalized
    end
  end
end
