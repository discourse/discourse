# frozen_string_literal: true

require "mini_mime"
require "base64"
require "digest"
require "tempfile"

class ::KanbanDevBot::BotController < ::ApplicationController
  requires_plugin "kanban-dev-bot"
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
      current_run = PluginStore.get(KanbanDevBot::STORE, "card-#{card.id}") || {}
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
        raw["notes"] = card.notes.to_s.split(KanbanDevBot::NOTE_PATTERN, 2).first.to_s +
          KanbanDevBot::NOTE_SEPARATOR + params[:message].to_s.first(20_000)
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
        KanbanDevBot::STORE,
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

  REVIEW_EXTENSIONS = %w[
    md
    txt
    rst
    csv
    pdf
    docx
    pptx
    xlsx
    zip
    png
    jpg
    jpeg
    gif
    webp
    diff
    patch
  ].freeze
  REVIEW_MAX_FILES = 24
  REVIEW_MAX_FILE_BYTES = 2 * 1024 * 1024
  REVIEW_MAX_TOTAL_BYTES = 8 * 1024 * 1024

  def review_artifacts
    with_review_card do |card, run_id|
      files = params.require(:files)
      unless files.is_a?(Array) && files.size.between?(1, REVIEW_MAX_FILES)
        raise Discourse::InvalidParameters
      end
      total = 0
      validated =
        files.map do |item|
          path = item.require(:path).to_s
          extension = File.extname(path).delete_prefix(".").downcase
          unless valid_review_path?(path) && REVIEW_EXTENSIONS.include?(extension)
            raise Discourse::InvalidParameters
          end
          encoded = item.require(:content_base64).to_s
          if encoded.bytesize > (REVIEW_MAX_FILE_BYTES * 4 / 3) + 4
            raise Discourse::InvalidParameters
          end
          begin
            content = Base64.strict_decode64(encoded)
          rescue ArgumentError
            raise Discourse::InvalidParameters
          end
          total += content.bytesize
          digest = Digest::SHA256.hexdigest(content)
          unless content.bytesize.between?(1, REVIEW_MAX_FILE_BYTES) &&
                   total <= REVIEW_MAX_TOTAL_BYTES && digest == item.require(:sha256)
            raise Discourse::InvalidParameters
          end
          [path, content, digest]
        end
      raise Discourse::InvalidParameters if validated.map(&:first).uniq.size != validated.size
      key = "review-artifacts-#{card.id}-#{run_id}"
      stored = PluginStore.get(KanbanDevBot::STORE, key) || {}
      new_keys = validated.map { |path, _, digest| Digest::SHA256.hexdigest("#{path}:#{digest}") }
      new_bytes =
        validated.each_with_index.sum do |(_, content, _), index|
          stored.key?(new_keys[index]) ? 0 : content.bytesize
        end
      if (stored.keys | new_keys).size > REVIEW_MAX_FILES ||
           stored.values.sum { |entry| entry.fetch("size", 0) } + new_bytes > REVIEW_MAX_TOTAL_BYTES
        raise Discourse::InvalidParameters
      end
      results =
        validated.map do |path, content, digest|
          identity = Digest::SHA256.hexdigest("#{path}:#{digest}")
          entry = stored[identity]
          upload = Upload.find_by(id: entry&.dig("upload_id"))
          unless upload
            Tempfile.create(["review-artifact", File.extname(path)]) do |file|
              file.binmode
              file.write(content)
              file.flush
              upload =
                UploadCreator.new(
                  file,
                  File.basename(path),
                  type: "composer",
                  skip_validations: true,
                ).create_for(current_user.id)
              raise Discourse::InvalidParameters unless upload.persisted? && upload.errors.empty?
            end
            stored[identity] = {
              "upload_id" => upload.id,
              "path" => path,
              "sha256" => digest,
              "size" => content.bytesize,
            }
            PluginStore.set(KanbanDevBot::STORE, key, stored)
          end
          { path: path, sha256: digest, upload_id: upload.id, short_url: upload.short_url }
        end
      render json: { files: results }
    end
  end

  def review_handoff
    with_review_card(columns: %w[REVIEW]) do |card, run_id|
      message = params.require(:message).to_s
      raise Discourse::InvalidParameters if message.blank? || message.length > 20_000
      digest = Digest::SHA256.hexdigest(message)
      posts = card.topic.posts.where(user_id: current_user.id, deleted_at: nil)
      post =
        posts
          .where(
            id: PostCustomField.where(name: "capybara_bot_run", value: run_id).select(:post_id),
          )
          .order(:post_number)
          .last
      unless post&.custom_fields&.dig("capybara_review_digest") == digest
        if post
          post.revise(current_user, { raw: message }, skip_validations: true)
          raise Discourse::InvalidParameters unless post.reload.raw == message
        else
          post =
            PostCreator.create!(
              current_user,
              topic_id: card.topic_id,
              raw: message,
              skip_validations: true,
            )
        end
        post.custom_fields["capybara_bot_run"] = run_id
        post.custom_fields["capybara_review_digest"] = digest
        post.save_custom_fields
      end
      render json: snapshot_card(card)
    end
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

  def valid_review_path?(path)
    path.present? && path.length <= 240 && !path.start_with?("/") &&
      !path.bytes.any? { |byte| byte < 32 || byte == 92 } &&
      path.split("/").none? { |part| part.in?(["", ".", ".."]) } &&
      !path.match?(
        %r{(^|/)(\.env(?:\..*)?|\.git|\.ssh|\.aws|credentials[^/]*|secrets?[^/]*|auth\.json|id_rsa|id_ed25519)(/|$)|\.(pem|key|p12|pfx)$}i,
      )
  end

  def with_review_card(columns: ["IN PROGRESS", "REVIEW"])
    raise Discourse::InvalidAccess unless current_user.username == "codex-bot"
    raise Discourse::InvalidAccess if @board.archived?
    card = @board.cards.find(params.require(:card_id))
    raise Discourse::InvalidParameters unless card.topic?
    guardian.ensure_can_see!(card.topic)
    guardian.ensure_can_create_post!(card.topic)
    card.with_lock do
      current_run = PluginStore.get(KanbanDevBot::STORE, "card-#{card.id}") || {}
      run_id = params.require(:run_id).to_s
      raise Discourse::InvalidParameters unless run_id.match?(/\A[a-zA-Z0-9-]{8,80}\z/)
      expected_status = card.column.title == "REVIEW" ? "review" : "running"
      unless columns.include?(card.column.title) && run_id == current_run["run_id"] &&
               current_run["status"] == expected_status &&
               current_run["version"] == card.column_changed_at.iso8601(6) &&
               params.require(:expected_run_id) == run_id &&
               params.require(:expected_version) == card.column_changed_at.iso8601(6)
        return render json: { error: "Card moved or run superseded" }, status: :conflict
      end
      yield card, run_id
    end
  end

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
    @board = Boards::Board.find(KanbanDevBot::BOARD_ID)
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
      notes: card.notes.to_s.split(KanbanDevBot::NOTE_PATTERN, 2).first.to_s,
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
      run: PluginStore.get(KanbanDevBot::STORE, "card-#{card.id}") || {},
    }
  end

  def image_upload?(upload)
    upload.extension.to_s.downcase.in?(%w[png jpg jpeg gif webp])
  end
end
