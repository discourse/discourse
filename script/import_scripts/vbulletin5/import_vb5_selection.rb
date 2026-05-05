# frozen_string_literal: true

# Imports a specific selection of vBulletin nodes that were missed by the main
# import (e.g. gallery posts skipped due to resume logic, or any node type that
# needs to be force-imported by nodeid).
#
# Reads node IDs from a file and imports each one as a topic or post, using the
# same logic as vbulletin5.rb. Already-imported nodes are skipped safely.
#
# Usage (single node):
#   NODEID=2885308 bundle exec ruby script/import_scripts/vbulletin5/import_vb5_selection.rb
#
# Usage (list of nodes):
#   NODE_LIST=/tmp/missing_gallery.txt bundle exec ruby script/import_scripts/vbulletin5/import_vb5_selection.rb
#
# NODE_LIST: path to a plain text file with one vBulletin node ID per line.

unless (ENV["NODE_LIST"] && !ENV["NODE_LIST"].empty?) || (ENV["NODEID"] && !ENV["NODEID"].empty?)
  puts "ERROR: set NODEID or NODE_LIST to a file of vBulletin node IDs"
  exit 1
end

nodeids =
  if ENV["NODE_LIST"] && !ENV["NODE_LIST"].empty?
    node_list_path = ENV["NODE_LIST"]
    unless File.exist?(node_list_path)
      puts "ERROR: NODE_LIST file not found: #{node_list_path}"
      exit 1
    end
    ids = File.readlines(node_list_path, chomp: true)
              .map(&:strip).reject(&:empty?).map(&:to_i).reject(&:zero?).uniq.sort
    if ids.empty?
      puts "ERROR: no valid node IDs found in #{node_list_path}"
      exit 1
    end
    puts "#{ids.size} node(s) to import from #{node_list_path}"
    ids
  else
    id = ENV["NODEID"].to_i
    if id == 0
      puts "ERROR: NODEID is not a valid integer"
      exit 1
    end
    puts "Importing single node #{id}"
    [id]
  end

ENV["IMPORT_LIBRARY_ONLY"] = "1"
require_relative "vbulletin5"
ENV.delete("IMPORT_LIBRARY_ONLY")

class ImportScripts::VBulletin5Selection < ImportScripts::VBulletin
  def initialize(nodeids)
    @nodeids = nodeids
    super()
  end

  def execute
    import_selected_nodes
    import_selected_attachments
    import_selected_gallery_photos
    post_process_selected_posts
  end

  def import_selected_nodes
    puts "", "importing #{@nodeids.size} selected node(s)..."

    id_list = @nodeids.join(",")

    nodes = mysql_query(<<~SQL).to_a
      SELECT t.nodeid AS threadid, t.contenttypeid, t.title, t.parentid AS forumid,
             t.open, t.userid AS postuserid, t.publishdate AS dateline,
             t.starter,
             nv.count views, 1 AS visible, t.sticky,
             CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw,
             lnk.url AS link_url, lnk.url_title AS link_url_title, lnk.meta AS link_meta,
             parent_ct.class AS parent_class,
             parent.authorname AS parent_authorname
      FROM #{DB_PREFIX}node t
      LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
      LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = t.nodeid
      LEFT JOIN #{DB_PREFIX}link lnk ON lnk.nodeid = t.nodeid
      LEFT JOIN #{DB_PREFIX}node parent ON parent.nodeid = t.parentid
      LEFT JOIN #{DB_PREFIX}contenttype parent_ct ON parent_ct.contenttypeid = parent.contenttypeid
      WHERE t.nodeid IN (#{id_list})
    SQL

    if nodes.empty?
      puts "  No nodes found in vBulletin for the given IDs"
      return
    end

    topic_nodes   = nodes.select { |n| n["parent_class"] == "Channel" }
    comment_nodes = nodes.select { |n| n["parent_class"] == "Text" && n["forumid"] != n["starter"] }
    reply_nodes   = nodes.select { |n| n["parent_class"] != "Channel" && !(n["parent_class"] == "Text" && n["forumid"] != n["starter"]) }

    puts "  #{topic_nodes.size} topic starter(s), #{reply_nodes.size} thread reply/replies, #{comment_nodes.size} comment(s)"

    unless topic_nodes.empty?
      @closed_topic_ids ||= []
      create_posts(topic_nodes, total: topic_nodes.size, offset: 0) do |topic|
        raw = build_raw(topic, topic["threadid"])
        next if raw.nil?

        topic_id = "thread-#{topic["threadid"]}"
        @closed_topic_ids << topic_id if topic["open"] == "0"

        t = {
          id:         topic_id,
          user_id:    user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title:      decode_html_entities(topic["title"].to_s).strip[0...255],
          category:   category_id_from_imported_category_id(topic["forumid"]),
          raw:        raw,
          created_at: parse_timestamp(topic["dateline"]),
          visible:    topic["visible"].to_i == 1,
          views:      topic["views"],
          post_create_action: proc { |p| puts "  [#{topic["threadid"]}] created: #{Discourse.base_url}/p/#{p.id}" },
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end
    end

    unless reply_nodes.empty?
      create_posts(reply_nodes, total: reply_nodes.size, offset: 0) do |post|
        raw = build_raw(post, post["threadid"])
        next if raw.nil?

        topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
        unless topic
          puts "  [#{post["threadid"]}] SKIP reply: parent topic not found"
          next
        end

        p = {
          id:         post["threadid"],
          user_id:    user_id_from_imported_user_id(post["postuserid"]) || Discourse::SYSTEM_USER_ID,
          topic_id:   topic[:topic_id],
          raw:        raw,
          created_at: parse_timestamp(post["dateline"]),
          hidden:     post["visible"].to_i != 1,
          post_create_action: proc { |p| puts "  [#{post["threadid"]}] created: #{Discourse.base_url}/p/#{p.id}" },
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end

    unless comment_nodes.empty?
      create_posts(comment_nodes, total: comment_nodes.size, offset: 0) do |comment|
        raw = build_raw(comment, comment["threadid"])
        next if raw.nil?

        # Comments resolve topic via starter, not parentid
        topic = topic_lookup_from_imported_post_id("thread-#{comment["starter"]}")
        unless topic
          puts "  [#{comment["threadid"]}] SKIP comment: parent topic thread-#{comment["starter"]} not found"
          next
        end

        parent_post = topic_lookup_from_imported_post_id(comment["forumid"].to_s)
        if parent_post
          raw = comment_attribution(parent_post, comment["parent_authorname"]) + raw
        end

        p = {
          id:         comment["threadid"],
          user_id:    user_id_from_imported_user_id(comment["postuserid"]) || Discourse::SYSTEM_USER_ID,
          topic_id:   topic[:topic_id],
          raw:        raw,
          created_at: parse_timestamp(comment["dateline"]),
          post_create_action: proc { |p| puts "  [#{comment["threadid"]}] created: #{Discourse.base_url}/p/#{p.id}" },
        }
        p[:reply_to_post_number] = parent_post[:post_number] if parent_post
        p
      end
    end

    # Print URLs for all selected nodes (covers already-existing posts too)
    puts ""
    @nodeids.each do |nodeid|
      post_id = PostCustomField.where(name: "import_id", value: "thread-#{nodeid}").first&.post_id
      post_id ||= PostCustomField.where(name: "import_id", value: nodeid.to_s).first&.post_id
      if post_id
        puts "  [#{nodeid}] #{Discourse.base_url}/p/#{post_id}"
      else
        puts "  [#{nodeid}] WARNING: not found in Discourse after import"
      end
    end
  end

  def import_selected_attachments
    puts "", "importing attachments for #{@nodeids.size} selected node(s)..."
    @nodeids.each do |nodeid|
      post_id = PostCustomField.where(name: "import_id", value: "thread-#{nodeid}").first&.post_id
      post_id ||= PostCustomField.where(name: "import_id", value: nodeid.to_s).first&.post_id
      next unless post_id
      post = Post.find_by(id: post_id)
      next unless post
      import_attachments_for_node(nodeid, post, @filedataid_to_upload_html)
    end
  end

  def import_selected_gallery_photos
    puts "", "importing gallery photos for selected node(s)..."
    id_list = @nodeids.join(",")

    photos = mysql_query(<<~SQL).to_a
      SELECT p.nodeid AS photo_nodeid, p.filedataid, p.caption,
             fd.extension, fd.userid,
             gallery.nodeid AS gallery_nodeid
      FROM #{DB_PREFIX}photo p
      LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = p.filedataid
      LEFT JOIN #{DB_PREFIX}node photo_node ON photo_node.nodeid = p.nodeid
      LEFT JOIN #{DB_PREFIX}node gallery ON gallery.nodeid = photo_node.parentid
      WHERE gallery.nodeid IN (#{id_list})
      ORDER BY p.filedataid
    SQL

    puts "  #{photos.size} photo(s) to process"
    return if photos.empty?

    photos.each do |photo|
      gallery_nodeid = photo["gallery_nodeid"]
      filedataid     = photo["filedataid"].to_i

      post_id = PostCustomField.where(name: "import_id", value: "thread-#{gallery_nodeid}").first&.post_id
      post_id ||= PostCustomField.where(name: "import_id", value: gallery_nodeid.to_s).first&.post_id
      unless post_id
        puts "  [gallery-photo-#{filedataid}] SKIP: Gallery post #{gallery_nodeid} not imported"
        next
      end
      post = Post.find_by(id: post_id)
      unless post
        puts "  [gallery-photo-#{filedataid}] SKIP: post_id=#{post_id} not found"
        next
      end

      real_filename = "#{filedataid}.#{photo["extension"]}"

      existing_upload =
        Upload.find_by(original_filename: "#{filedataid}.attach") ||
        Upload.find_by(original_filename: real_filename)
      if existing_upload
        html = html_for_upload(existing_upload, real_filename)
        unless post.raw.include?(html)
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [existing_upload.id], target: post)
        end
        next
      end

      filename = File.join(ATTACH_DIR, photo["userid"].to_s.split("").join("/"), "#{filedataid}.attach")
      unless File.exist?(filename)
        missing_label = photo["caption"].present? ? "#{photo["caption"]} (#{filedataid}.#{photo["extension"]})" : "#{filedataid}.#{photo["extension"]}"
        puts "  [gallery-photo-#{filedataid}] SKIP: file not found at #{filename}"
        unless post.raw.include?("* *(Missing photo:")
          post.raw += "\n* *(Missing photo: #{missing_label})*"
          post.save!
        end
        next
      end

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        unless post.raw.include?(html)
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [upl_obj.id], target: post)
        end
        puts "  [gallery-photo-#{filedataid}] imported: #{real_filename}"
      else
        puts "  [gallery-photo-#{filedataid}] WARNING: upload failed"
      end
    end
  end

  def post_process_selected_posts
    puts "", "post-processing selected posts..."
    @nodeids.each do |nodeid|
      post_id = PostCustomField.where(name: "import_id", value: "thread-#{nodeid}").first&.post_id
      post_id ||= PostCustomField.where(name: "import_id", value: nodeid.to_s).first&.post_id
      next unless post_id
      post = Post.find_by(id: post_id)
      next unless post
      new_raw = postprocess_post_raw(post.raw)
      if new_raw != post.raw
        post.raw = new_raw
        post.save!
      end
    rescue StandardError => e
      puts "  WARNING [#{nodeid}]: #{e.message.lines.first&.strip}"
    end
  end

  def build_raw(node, nodeid)
    raw =
      if node["contenttypeid"] == @link_typeid
        build_link_post_body(node["link_url"], node["link_url_title"], node["link_meta"])
      else
        begin
          preprocess_post_raw(node["raw"].to_s)
        rescue StandardError
          nil
        end
      end

    raw = gallery_placeholder(nodeid) if raw.blank? && node["contenttypeid"] == @gallery_typeid

    if node["contenttypeid"] == @poll_typeid
      poll_syntax = build_poll_syntax(nodeid)
      raw = (raw.presence || "") + "\n\n" + poll_syntax if poll_syntax
    end

    raw.blank? ? nil : raw
  end
end

ImportScripts::VBulletin5Selection.new(nodeids).perform
