# frozen_string_literal: true

module Boards
  class BoardSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :unicode_name,
               :slug,
               :category_ids,
               :tag_ids,
               :tag_names,
               :anonymous_can_read,
               :require_confirmation,
               :show_tags,
               :card_style,
               :show_topic_thumbnail,
               :archived,
               :old_slug_used,
               :can_archive,
               :can_unarchive,
               :can_write,
               :can_manage,
               :created_by,
               :columns,
               :acl

    def tag_ids
      visible_tag_ids
    end

    def tag_names
      visible_tag_ids.filter_map { |id| tag_name_map[id] }.sort
    end

    def anonymous_can_read
      object.anonymous_can_read?
    end

    def old_slug_used
      return false unless object.archived?
      if @options.key?(:used_slugs)
        @options[:used_slugs].include?(object.original_slug)
      else
        object.old_slug_used?
      end
    end

    def can_archive
      scope.can_archive_board?(object)
    end

    def can_unarchive
      scope.can_unarchive_board?(object)
    end

    def can_write
      scope.can_write_board?(object)
    end

    def can_manage
      scope.can_manage_board?(object)
    end

    def created_by
      return nil if object.created_by.blank?

      { username: object.created_by.username, avatar_template: object.created_by.avatar_template }
    end

    def columns
      object.columns.map do |column|
        ColumnSerializer.new(column, root: false, scope:, tag_name_map:).as_json
      end
    end

    def acl
      @options[:include_acl] ? AccessControlList.where(target: object).flattened_list : nil
    end

    private

    def visible_tag_ids
      @visible_tag_ids ||= object.tag_ids.select { |tag_id| tag_name_map.key?(tag_id) }
    end

    def tag_name_map
      @options[:tag_name_map] || {}
    end
  end
end
