# frozen_string_literal: true

class AdminDashboardSectionConfiguration
  KNOWN_SECTIONS = %w[highlights reports traffic engagement search].freeze

  def self.available_plugin_section_ids
    DiscoursePluginRegistry
      .admin_dashboard_sections
      .select { |s| !s[:enabled].respond_to?(:call) || s[:enabled].call }
      .map { |s| s[:id] }
  end

  def self.all_known_section_ids
    KNOWN_SECTIONS + available_plugin_section_ids
  end

  def self.sections
    known = all_known_section_ids

    persisted =
      AdminDashboardSection
        .where(section_id: known)
        .order(:position)
        .pluck(:section_id, :visible)
        .map { |id, visible| { id:, visible: } }
    not_persisted = (known - persisted.map { |s| s[:id] }).map { |id| { id:, visible: true } }

    persisted + not_persisted
  end

  def self.visible_section_ids
    sections.select { |s| s[:visible] }.map { |s| s[:id] }
  end

  def self.update(input_sections, actor:)
    sanitized =
      Array(input_sections)
        .filter_map do |s|
          attrs = (s.respond_to?(:to_unsafe_h) ? s.to_unsafe_h : s.to_h).symbolize_keys
          id = attrs[:id].to_s
          next if all_known_section_ids.exclude?(id)
          { id:, visible: ActiveModel::Type::Boolean.new.cast(attrs[:visible]) }
        end
        .uniq { |s| s[:id] }

    present_ids = sanitized.map { |s| s[:id] }
    missing = sections.reject { |s| present_ids.include?(s[:id]) }
    ordered = sanitized + missing

    now = Time.zone.now
    rows =
      ordered.each_with_index.map do |section, index|
        {
          section_id: section[:id],
          position: index,
          visible: section[:visible],
          created_at: now,
          updated_at: now,
        }
      end
    AdminDashboardSection.upsert_all(rows, unique_by: :section_id)

    StaffActionLogger.new(actor).log_custom(
      "update_dashboard_sections",
      layout: ordered.map { |s| "#{s[:id]}:#{s[:visible] ? "visible" : "hidden"}" }.join(", "),
    )

    sections
  end
end
