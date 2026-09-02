# frozen_string_literal: true

# name: boards
# about: Organize topics, and lightweight standalone "floater" cards, into configurable, drag-and-drop kanban-style boards, all with a purpose-built management UI and per-board access control
# meta_topic_id: 411414
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/boards
# required_version: 2.7.0

enabled_site_setting :boards_enabled

register_asset "stylesheets/boards-manage.scss"
register_asset "stylesheets/boards-board.scss"
register_asset "stylesheets/boards-oneboxes.scss"
register_asset "stylesheets/boards-topic-pill.scss"
register_asset "stylesheets/boards-add-from-topic-menu.scss"
register_svg_icon "table-columns"
register_svg_icon "boards"

module ::Boards
  PLUGIN_NAME = "boards"
end

require_relative "lib/boards/engine"

after_initialize do
  # Keep queued jobs from the standalone plugin executable across the deploy.
  legacy_jobs =
    if Jobs.const_defined?(:DiscourseKanban, false)
      Jobs.const_get(:DiscourseKanban, false)
    else
      Jobs.const_set(:DiscourseKanban, Module.new)
    end
  unless legacy_jobs.const_defined?(:SyncTopicForKanban, false)
    legacy_jobs.const_set(:SyncTopicForKanban, Jobs::Boards::SyncTopic)
  end
  unless legacy_jobs.const_defined?(:CardPostProcess, false)
    legacy_jobs.const_set(:CardPostProcess, Jobs::Boards::CardPostProcess)
  end

  reloadable_patch { |plugin| Guardian.prepend Boards::GuardianExtensions }

  # Register any column icons already in the DB so they appear in the SVG sprite
  begin
    if ActiveRecord::Base.connection.data_source_exists?(:discourse_kanban_columns) &&
         ActiveRecord::Base.connection.column_exists?(:discourse_kanban_columns, :default_sort)
      Boards::Column
        .where.not(icon: [nil, ""])
        .distinct
        .pluck(:icon)
        .each { |icon| DiscoursePluginRegistry.register_svg_icon(icon) }
    end
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    # Database may be unreachable (asset precompile) or may have pending migrations
    # during db:create / db:migrate bootstrap.
  end

  # When a column's icon changes, register it and expire the sprite cache
  add_model_callback(Boards::Column, :after_commit) do
    if saved_change_to_icon? && icon.present?
      DiscoursePluginRegistry.register_svg_icon(icon)
      SvgSprite.expire_cache
    end
  end

  add_to_serializer(:current_user, :can_manage_boards) { scope.can_manage_boards? }

  add_to_serializer(:current_user, :can_edit_any_boards) do
    scope.target_ids_with_any_acl_permissions(Boards::Board, %w[edit manage]).any?
  end

  add_to_class(:topic, :board_cards_map) { @board_cards_map }
  add_to_class(:topic, :board_cards_map=) { |cards| @board_cards_map = cards }

  TopicList.on_preload do |topics, topic_list|
    next unless SiteSetting.boards_enabled

    guardian = topic_list.current_user.present? ? topic_list.current_user.guardian : Guardian.new

    result = Boards::TopicBoardMemberships.call(guardian:, options: { topics: })
    cards_map = result[:cards_map]
    topics.each { |topic| topic.board_cards_map = cards_map.fetch(topic.id, {}) }
  end

  add_to_serializer(
    :topic_list_item,
    :board_memberships,
    include_condition: -> { SiteSetting.boards_enabled && board_memberships.present? },
  ) do
    @board_memberships ||=
      begin
        cards_map = object.board_cards_map
        if cards_map.nil?
          result =
            Boards::TopicBoardMemberships.call(guardian: scope, options: { topics: [object] })
          cards_map = result[:cards_map].fetch(object.id, {})
        end

        ActiveModel::ArraySerializer.new(
          cards_map.values,
          each_serializer: Boards::TopicBoardMembershipSerializer,
          scope:,
        ).as_json
      end
  end

  add_to_serializer(
    :topic_view,
    :board_memberships,
    include_condition: -> { SiteSetting.boards_enabled },
  ) do
    @board_memberships ||=
      begin
        topic = object.topic
        result = Boards::TopicBoardMemberships.call(guardian: scope, options: { topics: [topic] })
        cards_map = result[:cards_map].fetch(topic.id, {})
        ActiveModel::ArraySerializer.new(
          cards_map.values,
          each_serializer: Boards::TopicBoardMembershipSerializer,
          scope:,
        ).as_json
      end
  end

  DiscoursePluginRegistry.register_acl_target_class(Boards::Board, self)

  on(:topic_created) do |topic|
    Boards::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("Boards: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_tags_changed) do |topic, _|
    Boards::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("Boards: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_status_updated) do |topic, _, _|
    Boards::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("Boards: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_recovered) do |topic, _|
    Boards::TopicSync.sync_topic(topic)
  rescue StandardError => e
    Rails.logger.warn("Boards: failed to sync topic #{topic&.id}: #{e.message}")
  end

  on(:topic_destroyed) do |topic, _|
    Boards::TopicSync.remove_topic(topic.id)
  rescue StandardError => e
    Rails.logger.warn("Boards: failed to remove topic #{topic&.id}: #{e.message}")
  end

  Oneboxer.register_local_handler("boards/boards") do |url, route, opts|
    ::Boards::OneboxHandler.handle(url, route, opts)
  end

  InlineOneboxer.register_local_handler("boards/boards") do |url, route, opts|
    ::Boards::InlineOneboxHandler.handle(url, route, opts)
  end

  if defined?(Assignment)
    add_model_callback(Assignment, :after_commit) do
      next unless SiteSetting.boards_enabled?

      begin
        tid = topic_id
        next if tid.blank?

        Jobs.cancel_scheduled_job("Boards::SyncTopic", topic_id: tid)
        Jobs.enqueue_in(5.seconds, Jobs::Boards::SyncTopic, topic_id: tid)
      rescue StandardError => e
        Rails.logger.warn(
          "Boards: failed to enqueue sync after assignment change for topic #{tid}: #{e.message}",
        )
      end
    end
  end

  add_model_callback(Topic, :after_commit) do
    next unless SiteSetting.boards_enabled?
    next unless saved_changes?

    begin
      if saved_changes.key?("deleted_at") && deleted_at.present?
        Boards::TopicSync.remove_topic(id)
        next
      end

      tracked_changes = %w[category_id archetype visible]
      next if (saved_changes.keys & tracked_changes).empty?

      Boards::TopicSync.sync_topic(self)
    rescue StandardError => e
      Rails.logger.warn("Boards: after_commit sync failed for topic #{id}: #{e.message}")
    end
  end

  register_stat("total_boards", stat_type: :boards) { Boards::Statistics.total_boards }
  register_stat("created_boards", stat_type: :boards) { Boards::Statistics.created_boards }
  register_stat("viewed_boards", stat_type: :boards) { Boards::Statistics.viewed_boards }
  register_stat("active_boards", stat_type: :boards) { Boards::Statistics.active_boards }
  register_stat("active_users", stat_type: :boards) { Boards::Statistics.active_users }
  register_stat("participating_users", stat_type: :boards) do
    Boards::Statistics.participating_users
  end
end
