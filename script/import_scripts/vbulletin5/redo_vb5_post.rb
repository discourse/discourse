# frozen_string_literal: true

# Re-processes one or more vBulletin posts that have already been imported into Discourse. Also imports any
# attachments for the post that were not imported previously. Useful when you want to reprocess specific
# posts without running a full import. NOTE all nodes must already have been imported once! For nodes that
# have never been imported at all, see import_vb5_selection.rb.
#
# Usage (single post):
#   NODEID=2943053 bundle exec ruby script/import_scripts/vbulletin5/redo_vb5_post.rb
#
# Usage (list of posts):
#   NODE_LIST=/tmp/bbcode_nodeids.txt bundle exec ruby script/import_scripts/vbulletin5/redo_vb5_post.rb
#
# NODE_LIST MUST be a plain text file with one vBulletin node ID per line.
#
# The NODEID/node IDs MUST be vBulletin node IDs (not Discourse post IDs). For topic starters, the
# import_id is "thread-<nodeid>". For replies, the import_id is "<nodeid>".

# ---------------------------------------------------------------------------
# Build the list of node IDs to process
# ---------------------------------------------------------------------------

nodeids =
  if ENV["NODE_LIST"] && !ENV["NODE_LIST"].empty?
    path = ENV["NODE_LIST"]
    unless File.exist?(path)
      puts "ERROR: NODE_LIST file not found: #{path}"
      exit 1
    end
    ids = File.readlines(path, chomp: true).map(&:strip).reject(&:empty?).map(&:to_i).reject(&:zero?)
    if ids.empty?
      puts "ERROR: NODE_LIST file contains no valid node IDs: #{path}"
      exit 1
    end
    puts "Processing #{ids.size} node(s) from #{path}"
    ids
  elsif ENV["NODEID"] && !ENV["NODEID"].empty?
    id = ENV["NODEID"].to_i
    if id == 0
      puts "ERROR: NODEID is not a valid integer"
      exit 1
    end
    [id]
  else
    puts "ERROR: set NODEID or NODE_LIST environment variable"
    exit 1
  end

# ---------------------------------------------------------------------------
# Load the importer library and build the upload map once
# ---------------------------------------------------------------------------

ENV["IMPORT_LIBRARY_ONLY"] = "1"
require_relative "vbulletin5"

importer = ImportScripts::VBulletin.allocate.library_only_init

# Rebuild the filedataid->upload_html map from already-imported uploads
upload_map = importer.instance_variable_get(:@filedataid_to_upload_html)
Upload.where("original_filename ~ '^[0-9]+\\.attach$'").find_each do |upl|
  fid = upl.original_filename.to_i
  upload_map[fid] ||= importer.send(:html_for_upload, upl, upl.original_filename)
end
puts "  #{upload_map.size} upload(s) mapped" if upload_map.size > 0

link_typeid    = importer.instance_variable_get(:@link_typeid)
gallery_typeid = importer.instance_variable_get(:@gallery_typeid)
poll_typeid    = importer.instance_variable_get(:@poll_typeid)

# ---------------------------------------------------------------------------
# Per-node processing
# ---------------------------------------------------------------------------

def process_node(nodeid, importer, upload_map, link_typeid, gallery_typeid, poll_typeid)
  # Find the Discourse post
  import_id =
    if PostCustomField.where(name: "import_id", value: "thread-#{nodeid}").exists?
      "thread-#{nodeid}"
    else
      nodeid.to_s
    end
  post_id = PostCustomField.find_by(name: "import_id", value: import_id)&.post_id

  if post_id.nil?
    puts "ERROR [#{nodeid}]: no Discourse post found for import_id #{import_id}"
    return false
  end

  post = Post.find_by(id: post_id)
  if post.nil?
    puts "ERROR [#{nodeid}]: post_id #{post_id} not found in Discourse"
    return false
  end

  print "  [#{nodeid}] post #{post_id} (topic #{post.topic_id}): "

  # -------------------------------------------------------------------------
  # Import any attachments for this node that haven't been imported yet
  # -------------------------------------------------------------------------

  importer.send(:import_attachments_for_node, nodeid, post, upload_map)

  # -------------------------------------------------------------------------
  # Reprocess the post raw content
  # -------------------------------------------------------------------------

  row = importer.send(:mysql_query, <<~SQL).first
    SELECT n.contenttypeid,
           CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw,
           lnk.url AS link_url, lnk.url_title AS link_url_title, lnk.meta AS link_meta
    FROM node n
    LEFT JOIN text txt ON txt.nodeid = n.nodeid
    LEFT JOIN link lnk ON lnk.nodeid = n.nodeid
    WHERE n.nodeid = #{nodeid}
  SQL

  if row.nil?
    puts "ERROR [#{nodeid}]: node not found in vBulletin"
    return false
  end

  new_raw =
    if row["contenttypeid"] == link_typeid
      importer.send(:build_link_post_body, row["link_url"], row["link_url_title"], row["link_meta"])
    else
      importer.send(:preprocess_post_raw, row["raw"].to_s)
    end

  new_raw = importer.send(:gallery_placeholder, nodeid) if new_raw.blank? && row["contenttypeid"] == gallery_typeid

  if row["contenttypeid"] == poll_typeid
    poll_syntax = importer.send(:build_poll_syntax, nodeid)
    new_raw = (new_raw.presence || "") + "\n\n" + poll_syntax if poll_syntax
  end

  if new_raw.blank?
    puts "ERROR [#{nodeid}]: preprocessed raw is blank"
    return false
  end

  final_raw = importer.send(:postprocess_post_raw, new_raw)

  post.reload  # in case attachment imports changed it

  if final_raw == post.raw
    puts "unchanged: #{Discourse.base_url}/p/#{post_id}"
  else
    post.raw = final_raw
    post.save!
    puts "updated: #{Discourse.base_url}/p/#{post_id}"
  end

  # -------------------------------------------------------------------------
  # Import comments for this node if it is a thread starter
  # -------------------------------------------------------------------------

  if import_id.start_with?("thread-")
    importer.send(:import_comments_for_thread, nodeid)
  end

  # -------------------------------------------------------------------------
  # Import poll votes for this node
  # -------------------------------------------------------------------------

  poll = Poll.find_by(post: post, name: "poll")
  if poll
    vb_votes = importer.send(:mysql_query, <<~SQL).to_a
      SELECT pv.polloptionid, pv.userid
      FROM pollvote pv
      WHERE pv.nodeid = #{nodeid} AND pv.userid IS NOT NULL
    SQL

    options = importer.send(:mysql_query, <<~SQL).to_a
      SELECT polloptionid, title FROM polloption WHERE nodeid = #{nodeid} ORDER BY polloptionid
    SQL

    option_map = {}
    options.each do |opt|
      title  = importer.send(:decode_html_entities, opt["title"].to_s).strip
      digest = Digest::MD5.hexdigest(JSON.generate([title]))
      discourse_opt = PollOption.find_by(poll: poll, digest: digest)
      option_map[opt["polloptionid"]] = discourse_opt&.id
    end

    rows_to_insert = []
    anon_counts = Hash.new(0)

    vb_votes.each do |vote|
      discourse_uid  = UserCustomField.where(name: "import_id", value: vote["userid"].to_s).first&.user_id
      poll_option_id = option_map[vote["polloptionid"]]
      next unless poll_option_id

      if discourse_uid
        rows_to_insert << {
          poll_id:        poll.id,
          poll_option_id: poll_option_id,
          user_id:        discourse_uid,
          created_at:     Time.now,
          updated_at:     Time.now,
        }
      else
        anon_counts[poll_option_id] += 1
      end
    end

    PollVote.insert_all(rows_to_insert, unique_by: %i[poll_id poll_option_id user_id]) if rows_to_insert.any?
    anon_counts.each { |oid, count| PollOption.where(id: oid).update_all(anonymous_votes: count) }

    total_votes = rows_to_insert.size + anon_counts.values.sum
    puts "  poll votes: #{total_votes} (#{anon_counts.values.sum} anonymous) - #{Discourse.base_url}/t/#{post.topic_id}"
  end

  true
rescue StandardError => e
  puts "ERROR [#{nodeid}]: #{e.message.lines.first&.strip}"
  false
end

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

total   = nodeids.size
success = 0
failure = 0

nodeids.each_with_index do |nodeid, idx|
  print "[#{idx + 1}/#{total}] " if total > 1
  ok = process_node(nodeid, importer, upload_map, link_typeid, gallery_typeid, poll_typeid)
  ok ? success += 1 : failure += 1
end

if total > 1
  puts "", "Done: #{success} updated/unchanged, #{failure} errors (#{total} total)"
end
