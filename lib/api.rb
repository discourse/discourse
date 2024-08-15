# frozen_string_literal: true

module API
  def self.client
    @client ||=
      Faraday.new(url: DOCS_TARGET) do |conn|
        conn.request :multipart
        conn.request :url_encoded
        conn.request :retry,
                     {
                       methods: %i[get post delete put],
                       retry_statuses: [429],
                       max: 3,
                       retry_block: ->(env:, options:, retry_count:, exception:, will_retry_in:) do
                         puts "Rate limited... will retry in #{will_retry_in}s"
                       end,
                       exceptions: [Faraday::TooManyRequestsError]
                     }
        conn.response :json, content_type: "application/json"
        conn.response :raise_error
        conn.adapter Faraday.default_adapter
        conn.headers["Api-Key"] = DOCS_API_KEY
      end
  end

  def self.edit_post(post_id:, raw:, title: nil, category: nil)
    if dry_run?
      puts "  DRY RUN: skipping PUT /posts/#{post_id}"
      return
    end

    params = {
      post: {
        raw: raw,
        edit_reason: "Synced from github.com/discourse/discourse-developer-docs"
      }
    }
    params[:title] = title if title
    params[:category] = category if category
    client.put("/posts/#{post_id}", params)
  end

  def self.create_topic(external_id:, raw:, category:, title:)
    if dry_run?
      puts "  DRY RUN: skipping POST /posts"
      return
    end
    client.post("/posts", { title: title, raw: raw, external_id: external_id, category: category })
  end

  def self.trash_topic(topic_id:)
    if dry_run?
      puts "  DRY RUN: skipping DELETE /t/#{topic_id}.json"
      return
    end

    client.delete("/t/#{topic_id}.json")
  end

  def self.fetch_current_state
    result =
      client.post(
        "/admin/plugins/explorer/queries/#{DATA_EXPLORER_QUERY_ID}/run",
        { params: { category_id: CATEGORY_ID.to_s }.to_json }
      ).body

    raise "Data explorer query failed" if result["success"] != true

    if result["columns"] != %w[t_id first_p_id external_id title raw deleted_at is_index_topic]
      raise "Data explorer query returned unexpected columns: #{result["columns"].inspect}"
    end

    result["rows"].map do |row|
      {
        topic_id: row[0],
        first_post_id: row[1],
        external_id: row[2],
        title: row[3],
        raw: row[4],
        deleted_at: row[5],
        is_index_topic: row[6]
      }
    end
  end

  def self.restore_topic(topic_id:)
    path = "/t/#{topic_id}/recover.json"

    if dry_run?
      puts "  DRY RUN: skipping PUT #{path}"
      return
    end

    client.put(path)
  end

  def self.upload_file(path)
    if dry_run?
      puts "  DRY RUN: skipping POST /uploads.json"
      return { "short_url" => "upload://placeholder" }
    end

    client.post(
      "/uploads.json",
      { type: "composer", synchronous: true, file: Faraday::UploadIO.new(path, "image/png") }
    ).body
  end

  def self.dry_run?
    [nil, true].include?(DRY_RUN)
  end
end
