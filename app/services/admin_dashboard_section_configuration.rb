# frozen_string_literal: true

class AdminDashboardSectionConfiguration
  KNOWN_SECTIONS = %w[highlights reports traffic engagement search].freeze

  ACTIVITY_BY_CATEGORY_MAX = 10
  WHOS_POSTING_MAX = 10

  SUPPORTED_SETTINGS = {
    "engagement" => {
      "activity_by_category" => {
        permit: [{ category_ids: [] }],
        validate: ->(attrs) do
          ids = attrs[:category_ids]
          raise Discourse::InvalidParameters.new(:category_ids) if !ids.is_a?(Array)

          parsed = ids.map { |id| Integer(id, exception: false) }

          if parsed.size > ACTIVITY_BY_CATEGORY_MAX || parsed.any?(&:nil?) ||
               parsed.uniq.size != parsed.size
            raise Discourse::InvalidParameters.new(:category_ids)
          end

          if parsed.present? && Category.where(id: parsed).count != parsed.size
            raise Discourse::InvalidParameters.new(:category_ids)
          end

          { "category_ids" => parsed }
        end,
      },
      "whos_posting" => {
        permit: [{ category_ids: [] }],
        validate: ->(attrs) do
          ids = attrs[:category_ids]
          raise Discourse::InvalidParameters.new(:category_ids) if !ids.is_a?(Array)

          parsed = ids.map { |id| Integer(id, exception: false) }

          if parsed.size > WHOS_POSTING_MAX || parsed.any?(&:nil?) ||
               parsed.uniq.size != parsed.size
            raise Discourse::InvalidParameters.new(:category_ids)
          end

          if parsed.present? && Category.where(id: parsed).count != parsed.size
            raise Discourse::InvalidParameters.new(:category_ids)
          end

          { "category_ids" => parsed }
        end,
      },
    },
  }.freeze

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

  def self.settings_for(section_id)
    AdminDashboardSection.where(section_id: section_id.to_s).pick(:settings) || {}
  end

  def self.setting_definition(section_id, key)
    section_id = section_id.to_s
    key = key.to_s

    SUPPORTED_SETTINGS.dig(section_id, key) || plugin_setting_definition(section_id, key)
  end

  def self.plugin_setting_definition(section_id, key)
    entry = DiscoursePluginRegistry.admin_dashboard_sections.find { |s| s[:id] == section_id }
    return nil if entry.nil?
    return nil if entry[:enabled].respond_to?(:call) && !entry[:enabled].call

    klass = entry[:settings]&.dig(key)
    return nil if klass.nil?

    { permit: klass.permit, validate: ->(attrs) { klass.validate(attrs) } }
  end

  def self.update_setting(section_id:, key:, attrs:)
    section_id = section_id.to_s
    key = key.to_s

    definition = setting_definition(section_id, key)
    raise Discourse::InvalidParameters.new(:setting_key) if definition.nil?

    value = definition[:validate].call(attrs.to_h.with_indifferent_access)

    record =
      AdminDashboardSection.find_or_create_by!(section_id:) do |r|
        r.position = (AdminDashboardSection.maximum(:position) || -1) + 1
        r.visible = true
      end

    record.with_lock { record.update!(settings: record.settings.to_h.deep_merge(key => value)) }

    record.settings
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
