require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require File.expand_path(File.dirname(__FILE__) + "/drupal.rb")

require "mysql2"

class ImportScripts::DrupalQA < ImportScripts::Drupal

  def create_forum_topics
    puts '', "creating forum topics"

    total_count = @client.query("
        SELECT COUNT(*) count
          FROM node n
         WHERE n.type = 'question'
           AND n.status = 1;").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT n.nid,
               n.title,
               MIN(t.field_question_tags_tid) AS tid,
               n.uid,
               n.created,
               f.body_value AS body
        FROM node AS n
          LEFT OUTER JOIN field_data_field_question_tags AS t on t.entity_id = n.nid
          INNER JOIN field_data_body AS f ON f.entity_id = n.nid
        WHERE n.type = 'question'
          AND n.status = 1
        GROUP BY n.nid, n.title, n.uid, n.created, f.body_value
        LIMIT #{batch_size}
        OFFSET #{offset}
      ", cache_rows: false);

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |row|
        {
          id: "nid:#{row['nid']}",
          user_id: user_id_from_imported_user_id(row['uid']) || -1,
          category: category_from_imported_category_id(row['tid']).try(:name),
          raw: row['body'],
          created_at: Time.zone.at(row['created']),
          pinned_at: nil,
          title: row['title'].try(:strip)
        }
      end
    end
  end

  def create_replies
    puts '', "creating replies in topics"

    total_count = @client.query("
        SELECT COUNT(*) count
          FROM node n
         WHERE n.type = 'answer'
           AND n.status = 1;").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|

      results = @client.query("
        SELECT n.nid AS cid,
               q.field_answer_question_nid AS nid,
               n.uid,
               n.created,
               f.comment_body_value AS body
        FROM node AS n
          INNER JOIN field_data_field_answer_question AS q ON q.entity_id = n.nid
          INNER JOIN field_data_comment_body AS f ON f.entity_id = n.nid
        WHERE n.status = 1
          AND n.type = 'answer'
        LIMIT #{batch_size}
        OFFSET #{offset}
      ", cache_rows: false)

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row['nid']}")
        if topic_mapping && topic_id = topic_mapping[:topic_id]
          h = {
            id: "cid:#{row['cid']}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row['uid']) || -1,
            raw: row['body'],
            created_at: Time.zone.at(row['created']),
          }
          h
        else
          puts "No topic found for comment #{row['cid']}"
          nil
        end
      end
    end
  end

end

if __FILE__==$0
  ImportScripts::DrupalQA.new.perform
end
