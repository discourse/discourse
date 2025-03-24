# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Converter < ::Migrations::Converters::Base::Converter
    def initialize(settings)
      super
      @source_db = ::Migrations::Database::Adapter::Postgres.new(settings[:source_db])
      benchmark_loading
    end

    def step_args(step_class)
      { source_db: @source_db }
    end

    def benchmark_loading
      intermediate_db = create_database
      topic_users = Set.new

      start = Time.now

      topic_users =
        @source_db.query_array(
          "SELECT gs.n AS multiplier, user_id, topic_id FROM topic_users
JOIN generate_series(1, 10) gs(n) ON true",
        ).to_set

      puts "Loading done in #{Time.now - start} seconds"

      start = Time.now

      topic_users.each { |topic_user| topic_users.include?(topic_user) }

      puts "Checking done in #{Time.now - start} seconds"

      # start = Time.now
      #
      # intermediate_db.execute <<~SQL
      #   CREATE TABLE topic_users (
      #     user_id NUMBER,
      #     topic_id NUMBER
      #   )
      # SQL
      #
      # sql = <<~SQL
      #   INSERT INTO topic_users (user_id, topic_id)
      #   VALUES (?, ?)
      # SQL
      #
      # @source_db
      #   .query_array("SELECT user_id, topic_id FROM topic_users")
      #   .each { |row| intermediate_db.insert(sql, row) }
      # intermediate_db.commit_transaction
      #
      # intermediate_db.execute <<~SQL
      #   CREATE UNIQUE INDEX topic_users_pk ON topic_users(user_id, topic_id);
      # SQL
      #
      # puts "Loading and writing done in #{Time.now - start} seconds"
    end

    # def benchmark_loading
    #   intermediate_db = create_database
    #
    #   start = Time.now
    #
    #   usernames = @source_db.query("SELECT username_lower, id FROM users").to_a
    #
    #   puts "Loading done in #{Time.now - start} seconds"
    #
    #   start = Time.now
    #
    #   intermediate_db.execute <<~SQL
    #     CREATE TEMP TABLE usernames_lower (
    #       username TEXT PRIMARY KEY,
    #       discourse_user_id NUMBER
    #     )
    #   SQL
    #
    #   sql = <<~SQL
    #     INSERT INTO usernames_lower (username, discourse_user_id)
    #     VALUES (?, ?)
    #   SQL
    #
    #   @source_db
    #     .query_array("SELECT username_lower, id FROM users")
    #     .each { |row| intermediate_db.insert(sql, row) }
    #
    #   puts "Loading and writing done in #{Time.now - start} seconds"
    # end
  end
end
