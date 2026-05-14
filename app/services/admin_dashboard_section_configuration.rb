# frozen_string_literal: true

class AdminDashboardSectionConfiguration
  KNOWN_SECTIONS = %w[highlights reports traffic engagement].freeze

  def self.visible_section_ids
    raw = SiteSetting.admin_dashboard_sections.to_s
    return [] if raw.empty?

    ids = raw.split("|").map(&:strip).uniq.select { |id| KNOWN_SECTIONS.include?(id) }
    ids.empty? ? KNOWN_SECTIONS.dup : ids
  end

  def self.sections
    visible = visible_section_ids
    hidden = KNOWN_SECTIONS - visible
    visible.map { |id| { id: id, visible: true } } + hidden.map { |id| { id: id, visible: false } }
  end

  def self.update(input_sections, actor:)
    visible_ids =
      Array(input_sections)
        .select { |s| ActiveModel::Type::Boolean.new.cast(s[:visible] || s["visible"]) }
        .map { |s| (s[:id] || s["id"]).to_s }
        .uniq
        .select { |id| KNOWN_SECTIONS.include?(id) }

    SiteSetting.set_and_log("admin_dashboard_sections", visible_ids.join("|"), actor)
    sections
  end
end
