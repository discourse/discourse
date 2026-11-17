# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::Discourse::Posts do
  describe "#items" do
    it "resolves a reply whose parent is outside the partition" do
      Dir.mktmpdir do |dir|
        Migrations::Database.connect(File.join(dir, "source.db")) do |source_db|
          source_db.define_singleton_method(:chunk_filter) do |key, lower, upper, base:|
            columns = Array(key).join(", ")
            conditions = [base, "(#{columns}) >= (#{lower.join(", ")})"]
            conditions << "(#{columns}) < (#{upper.join(", ")})" if upper
            conditions.compact.join(" AND ")
          end
          source_db.execute(<<~SQL)
            CREATE TABLE posts (
              id INTEGER PRIMARY KEY,
              action_code,
              created_at,
              deleted_at,
              deleted_by_id,
              hidden,
              hidden_at,
              hidden_reason_id,
              last_editor_id,
              like_count,
              locale,
              locked_by_id,
              raw,
              topic_id INTEGER NOT NULL,
              post_number INTEGER NOT NULL,
              post_type,
              reply_to_post_number INTEGER,
              reply_to_user_id,
              sort_order,
              user_deleted,
              user_id,
              wiki,
              cooked TEXT
            )
          SQL
          source_db.execute(<<~SQL)
            INSERT INTO posts (id, topic_id, post_number, reply_to_post_number)
            VALUES (101, 10, 1, NULL), (205, 10, 2, 1), (901, 20, 1, NULL)
          SQL

          items = described_class.source_class.new(source_db:, chunk: [[10, 2], nil]).items.to_a

          expect(items.map { |item| [item[:id], item[:reply_to_post_id]] }).to eq(
            [[205, 101], [901, nil]],
          )
          expect(items).to all(satisfy { |item| !item.key?(:cooked) })
        end
      end
    end
  end
end
