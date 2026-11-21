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

    SEED_LINK_TYPES = {
      "profile_picture" => "account",
      "profile" => "profile",
      "guidelines" => "custom",
      "notifications" => "notifications",
    }.freeze

    def self.read
      configuration =
        PluginStore.get(PLUGIN_NAME, "checklist") ||
          {
            "items" => seeded_items.select { |item| DEFAULT_ITEMS.include?(item["id"]) },
            "revision" => 0,
          }
      configuration.merge("bank" => bank_for(configuration["items"], configuration))
    end

    def self.seeded_items
      guidelines = Topic.find_by(id: SiteSetting.guidelines_topic_id)
      ITEMS.map do |id|
        type = SEED_LINK_TYPES.fetch(id)
        {
          "id" => id,
          "title" => I18n.t("lovelace.items.#{id}.title"),
          "description" => I18n.t("lovelace.items.#{id}.description"),
          "button_text" => I18n.t("lovelace.items.#{id}.button_text"),
          "link_type" => type,
          "url" =>
            SETTINGS_PATHS[type] || guidelines&.relative_url&.delete_prefix(Discourse.base_path) ||
              "/guidelines",
        }
      end
    end

    def self.bank_for(items, previous)
      selected_ids = items.map { |item| item["id"] }
      available = previous["items"] + (previous["bank"] || [])
      seeded_items.filter_map do |seed|
        next if selected_ids.include?(seed["id"])
        available.find { |item| item["id"] == seed["id"] } || seed
      end
    end

    def self.unmodified_seed_ids(items)
      seeds = seeded_items.index_by { |seed| seed["id"] }
      items.filter_map { |item| item["id"] if item == seeds[item["id"]] }
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

    ITEMS = %w[profile_picture profile guidelines notifications].freeze
    DEFAULT_ITEMS = %w[profile_picture profile guidelines].freeze

    def self.item_ids
      PluginStore.get(PLUGIN_NAME, "checklist_items") || DEFAULT_ITEMS
    end

    def self.update!(ids)
      unless ids.is_a?(Array) && ids.all? { |id| ITEMS.include?(id) } && ids.uniq == ids
        raise Discourse::InvalidParameters.new(:item_ids)
      end

      PluginStore.set(PLUGIN_NAME, "checklist_items", ids)
    end

    def self.for_user(user)
      selected = item_ids
      result = { items: selected.map { |id| item(id, user) } }
      result[:bank] = (ITEMS - selected).map { |id| item(id, user) } if user.admin?
      result
    end

    def self.item(id, user)
      preferences = "#{Discourse.base_path}/u/#{user.username_lower}/preferences"
      url =
        case id
        when "profile_picture"
          "#{preferences}/account"
        when "profile"
          "#{preferences}/profile"
        when "notifications"
          "#{preferences}/notifications"
        when "guidelines"
          Topic.find_by(id: SiteSetting.guidelines_topic_id)&.relative_url ||
            "#{Discourse.base_path}/guidelines"
        end

      {
        id: id,
        title: I18n.t("lovelace.items.#{id}.title"),
        description: I18n.t("lovelace.items.#{id}.description"),
        button_text: I18n.t("lovelace.items.#{id}.button_text"),
        url: url,
      }
    end
    private_class_method :item
  end
end
