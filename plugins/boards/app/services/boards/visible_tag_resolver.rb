# frozen_string_literal: true

module Boards
  module VisibleTagResolver
    def self.resolve_names!(tag_names, guardian:)
      names = Array(tag_names).compact_blank.map(&:to_s)
      return [] if names.empty?

      visible_tags =
        DiscourseTagging
          .visible_tags(guardian)
          .where_name(names)
          .index_by { |tag| tag.name.downcase }
      resolved_ids = []
      missing_names = []

      names.each do |name|
        tag = visible_tags[name.downcase]
        if tag && guardian.can_see_tag?(tag)
          resolved_ids << tag.id
        elsif guardian.can_create_tag?
          cleaned_name = DiscourseTagging.clean_tag(name)
          if cleaned_name.present? && !Tag.where_name([cleaned_name]).exists?
            resolved_ids << Tag.create!(name: cleaned_name).id
          else
            missing_names << name
          end
        else
          missing_names << name
        end
      end

      if missing_names.any?
        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_names", tag_names: missing_names.join(", ")),
              )
      end

      resolved_ids
    end

    def self.resolve_name!(tag_name, guardian:)
      resolve_names!([tag_name], guardian:).first
    rescue Discourse::InvalidParameters
      raise Discourse::InvalidParameters.new(
              I18n.t("boards.errors.unknown_tag_name", tag_name: tag_name),
            )
    end
  end
end
