# frozen_string_literal: true

require "cgi"

module Migrations::Converters::Phpbb3
  class Posts < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    run_in_parallel(true)

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL)
        SELECT COUNT(*)
        FROM phpbb_posts
      SQL
    end

    def items
      query(<<~SQL)
        SELECT p.post_id, p.topic_id, p.poster_id, p.post_text, p.post_time, p.bbcode_uid
        FROM phpbb_posts p
        ORDER BY p.post_id
      SQL
    end

    def process_item(item)
      raw = process_raw(item[:post_text], item[:bbcode_uid])
      created_at = Time.at(item[:post_time]).utc

      IntermediateDB::Post.create(
        original_id: item[:post_id],
        topic_id: item[:topic_id],
        user_id: item[:poster_id],
        raw:,
        original_raw: item[:post_text],
        created_at:,
        post_type: IntermediateDB::Enums::PostType::REGULAR,
      )
    end

    private

    def process_raw(text, bbcode_uid)
      return "" if text.blank?

      processed = text.dup
      processed.gsub!(/:#{Regexp.escape(bbcode_uid)}([\]\:])/, '\1') if bbcode_uid.present?
      processed = CGI.unescapeHTML(processed)
      processed.gsub!(/:\w{5,8}\]/, "]")
      processed.gsub!(%r{\[/?color(=#?[a-z0-9]*)?\]}i, "")
      processed.gsub!(%r{<br\s*/?>}i, "\n")
      processed
    end
  end
end
