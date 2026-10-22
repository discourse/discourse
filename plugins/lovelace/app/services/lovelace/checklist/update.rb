# frozen_string_literal: true

module ::Lovelace
  class Checklist::Update
    include Service::Base

    policy :plugin_enabled
    policy :can_configure_checklist

    params do
      attribute :items
      attribute :revision, :string

      validate :normalize_items

      def normalize_items
        raw_items = items
        if raw_items.is_a?(Array)
          raw_items = raw_items.map { |item| item.is_a?(Hash) ? item.deep_stringify_keys : item }
        end
        self.items = Checklist.normalize(raw_items)
      rescue Discourse::InvalidParameters => error
        errors.add(:items, error.message)
      end
    end

    lock do
      model :current_checklist
      policy :revision_matches
      model :checklist, :save_checklist
    end

    private

    def plugin_enabled
      SiteSetting.lovelace_enabled
    end

    def can_configure_checklist(guardian:)
      guardian.is_admin?
    end

    def fetch_current_checklist
      Checklist.read
    end

    def revision_matches(params:, current_checklist:)
      params.revision.to_s == current_checklist["revision"].to_s
    end

    def save_checklist(params:, current_checklist:)
      checklist = {
        "items" => params.items,
        "bank" => Checklist.bank_for(params.items, current_checklist),
        "revision" => current_checklist["revision"] + 1,
      }
      PluginStore.set(PLUGIN_NAME, "checklist", checklist)
      checklist
    end
  end
end
