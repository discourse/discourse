# frozen_string_literal: true

require "mini_mime"

class ::CodexBoardBot::BotController < ::ApplicationController
  requires_plugin "capybara"
  skip_before_action :preload_json, :check_xhr, only: :upload
  before_action :ensure_logged_in
  before_action :ensure_development_board

  def setup
    guardian.ensure_is_admin!
    user = User.find_by_username("codex-bot")
    user ||=
      User.create!(
        username: "codex-bot",
        email: "codex-bot@localhost.invalid",
        password: SecureRandom.base64(36),
        active: true,
        approved: true,
      )
    user.update!(active: true, approved: true)
    user.activate
    acl = AccessControlList.find_or_initialize_by(target: @board, permission: "edit")
    acl.owner = Boards::PLUGIN_NAME
    acl.allowed_user_ids = (acl.allowed_user_ids + [user.id]).uniq
    acl.save!
    ensure_archived_column
    render json: { username: user.username }
  end

  def snapshot
    cards =
      @board
        .cards
        .includes(:column, :topic)
        .filter_map do |card|
          next if card.topic? && !guardian.can_see?(card.topic)
          snapshot_card(card)
        end
    render json: {
             board_id: @board.id,
             archived: @board.archived?,
             columns: @board.columns.pluck(:title, :id).to_h,
             cards: cards,
           }
  end

  def transition
    card = @board.cards.find(params.require(:card_id))
    guardian.ensure_can_see!(card.topic) if card.topic?
    original_column_id = nil
    card.with_lock do
      original_column_id = card.column_id
      current_run = PluginStore.get(CodexBoardBot::STORE, "card-#{card.id}") || {}
      command = params.require(:command).to_s
      commands = {
        "claim" => ["TODO", "IN PROGRESS", "running"],
        "review" => ["IN PROGRESS", "REVIEW", "review"],
        "failed" => ["IN PROGRESS", "IN PROGRESS", "failed"],
        "review_failed" => %w[REVIEW REVIEW failed],
        "integrating" => %w[DONE DONE integrating],
        "integration_failed" => %w[DONE DONE integration_failed],
        "done" => %w[DONE DONE done],
        "archive" => %w[DONE ARCHIVED done],
      }
      raise Discourse::InvalidParameters unless commands.key?(command)
      run_id = params.require(:run_id).to_s
      raise Discourse::InvalidParameters unless run_id.match?(/\A[a-zA-Z0-9-]{8,80}\z/)
      from_title, target_title, status = commands.fetch(command)
      version = card.column_changed_at.iso8601(6)
      if current_run["run_id"] == run_id && current_run["status"] == status &&
           current_run["version"] == version && card.column.title == target_title
        return render json: snapshot_card(card)
      end
      if version != params.require(:expected_version) || card.column.title != from_title
        return(render json: { error: "Card moved since it was read" }, status: :conflict)
      end
      if command != "claim" &&
           (
             params.require(:expected_run_id) != current_run["run_id"] ||
               run_id != current_run["run_id"]
           )
        return render json: { error: "Run superseded" }, status: :conflict
      end
      target = @board.columns.find_by!(title: target_title)
      raw = { "column_id" => target.id }
      if params.key?(:message) && card.floater?
        raw["notes"] = card.notes.to_s.split(CodexBoardBot::NOTE_PATTERN, 2).first.to_s +
          CodexBoardBot::NOTE_SEPARATOR + params[:message].to_s.first(20_000)
      end
      result =
        Boards::UpdateCard.call(
          guardian: guardian,
          params: raw.merge("board_id" => @board.id, "id" => card.id),
          options: {
            raw_card_params: raw,
          },
        )
      raise Discourse::InvalidParameters unless result.success?
      card.reload
      PluginStore.set(
        CodexBoardBot::STORE,
        "card-#{card.id}",
        { run_id: run_id, status: status, version: card.column_changed_at.iso8601(6) },
      )
      if card.topic? && params[:message].present? &&
           status.in?(%w[review failed integrating integration_failed done])
        post =
          PostCreator.create!(
            current_user,
            topic_id: card.topic_id,
            raw: params[:message].to_s.first(20_000),
            skip_validations: true,
          )
        post.custom_fields["capybara_bot_run"] = run_id
        post.save_custom_fields
      end
    end
    payload = Boards::CardSerializer.new(card, root: false, scope: guardian).as_json
    if card.column_id != original_column_id
      Boards::Publisher.publish_card_moved!(
        @board,
        payload,
        original_column_id,
        acting_user: current_user,
        client_id: nil,
      )
      if card.topic?
        Boards::Publisher.publish_topic_memberships_changed!(
          card.topic,
          client_id: nil,
          refresh_stream: false,
        )
      end
    else
      Boards::Publisher.publish_card_updated!(@board, payload, client_id: nil)
    end
    render json: snapshot_card(card)
  end

  def upload
    upload = Upload.find(params.require(:id))
    posts =
      Post.where(
        topic_id: @board.cards.where(card_type: :topic).select(:topic_id),
        deleted_at: nil,
        post_type: Post.types[:regular],
      )
    references =
      UploadReference.where(upload_id: upload.id, target_type: "Post", target_id: posts.select(:id))
    permitted = references.any? { |reference| guardian.can_see?(reference.target.topic) }
    raise Discourse::NotFound unless permitted && image_upload?(upload)
    path = Discourse.store.path_for(upload)
    raise Discourse::NotFound unless path && File.file?(path)
    send_file path,
              filename: upload.original_filename,
              disposition: "inline",
              type: MiniMime.lookup_by_extension(upload.extension).content_type
  end

  private

  def ensure_archived_column
    @board.with_lock do
      done = @board.columns.find_by!(title: "DONE")
      archived = @board.columns.find_by(title: "ARCHIVED")
      unless archived
        result =
          Boards::CreateColumn.call(
            guardian: guardian,
            params: {
              board_id: @board.id,
              title: "ARCHIVED",
            },
          )
        raise Discourse::InvalidParameters unless result.success?
        archived = result[:column]
      end
      loop do
        ids = @board.columns.order(:position, :id).pluck(:id)
        archived_index = ids.index(archived.id)
        done_index = ids.index(done.id)
        break if archived_index == done_index + 1
        direction = archived_index <= done_index ? 1 : -1
        result =
          Boards::MoveColumn.call(
            guardian: guardian,
            params: {
              board_id: @board.id,
              column_id: archived.id,
              direction: direction,
            },
          )
        raise Discourse::InvalidParameters unless result.success?
      end
    end
  end

  def ensure_development_board
    raise Discourse::NotFound if Rails.env.production?
    @board = Boards::Board.find(CodexBoardBot::BOARD_ID)
    permitted =
      (
        if action_name == "snapshot"
          guardian.can_read_board?(@board)
        else
          guardian.can_write_board?(@board)
        end
      )
    raise Discourse::InvalidAccess unless permitted
    unless current_user.admin? || current_user.username == "codex-bot"
      raise Discourse::InvalidAccess
    end
  end

  def snapshot_card(card)
    posts =
      if card.topic?
        human_posts =
          card
            .topic
            .posts
            .where(deleted_at: nil, post_type: Post.types[:regular])
            .where.not(user_id: User.where(username: "codex-bot").select(:id))
            .where.not(id: PostCustomField.where(name: "capybara_bot_run").select(:post_id))
            .includes(:user, :uploads)
            .order(:post_number)
        human_posts.where(post_number: 1).to_a + human_posts.where.not(post_number: 1).last(99)
      else
        []
      end
    attachments =
      posts.flat_map { |post| post.uploads.select { |upload| image_upload?(upload) } }.uniq(&:id)
    {
      id: card.id,
      title: card.resolved_title,
      notes: card.notes.to_s.split(CodexBoardBot::NOTE_PATTERN, 2).first.to_s,
      topic_id: card.topic_id,
      discussion:
        posts.map do |post|
          { id: post.id, author: post.user&.username, raw: post.raw, post_number: post.post_number }
        end,
      attachments:
        attachments.map do |upload|
          {
            id: upload.id,
            url: "/codex-board-bot/uploads/#{upload.id}",
            original_filename: upload.original_filename,
            width: upload.width,
            height: upload.height,
          }
        end,
      column_id: card.column_id,
      column: card.column.title,
      version: card.column_changed_at.iso8601(6),
      run: PluginStore.get(CodexBoardBot::STORE, "card-#{card.id}") || {},
    }
  end

  def image_upload?(upload)
    upload.extension.to_s.downcase.in?(%w[png jpg jpeg gif webp])
  end
end
