# frozen_string_literal: true

# The named parts of the forum that generated theme styles may restyle, from
# config/appearance_styles/areas.yml.
module AppearanceStyles
  class AreaCatalog
    CONFIG_PATH = Rails.root.join("config/appearance_styles/areas.yml")

    Area =
      Data.define(
        :key,
        :label,
        :selector,
        :states,
        :hideable,
        :sizeable,
        :text_color,
        :background,
        :hover_background,
      )

    PAGE_BACKGROUND = "var(--secondary)"

    def self.instance
      @instance ||= new
    end

    def initialize
      @areas =
        YAML
          .safe_load_file(CONFIG_PATH)
          .to_h do |key, entry|
            [
              key,
              Area.new(
                key:,
                label: entry.fetch("label"),
                selector: entry.fetch("selector"),
                states: Array(entry["states"]).freeze,
                hideable: entry["hideable"] == true,
                sizeable: entry["sizeable"] == true,
                text_color: entry["text_color"],
                background: entry["background"] || PAGE_BACKGROUND,
                hover_background: entry["hover_background"],
              ),
            ]
          end
          .freeze
    end

    def [](key)
      @areas[key.to_s]
    end

    def all
      @areas.values
    end
  end
end
