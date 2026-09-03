# frozen_string_literal: true

describe DiscourseDataExplorer::DataExplorer do
  describe ".strip_comments" do
    it "removes line comments, keeping the newline" do
      expect(described_class.strip_comments("SELECT 1 -- hi\nFROM t")).to eq("SELECT 1 \nFROM t")
    end

    it "removes nested block comments" do
      expect(described_class.strip_comments("SELECT /* a /* b */ c */ 1")).to eq("SELECT   1")
    end

    it "keeps comment markers inside quoted identifiers" do
      expect(described_class.strip_comments(%{SELECT 1 AS "-- a"})).to eq(%{SELECT 1 AS "-- a"})
    end

    it "keeps comment markers inside dollar-quoted strings" do
      expect(described_class.strip_comments("SELECT $q$-- a$q$")).to eq("SELECT $q$-- a$q$")
    end

    it "does not let an escaped quote in an E'' string swallow a comment" do
      expect(described_class.strip_comments("SELECT E'a\\'b' -- c")).to eq("SELECT E'a\\'b' ")
    end

    it "passes unterminated literals through" do
      expect(described_class.strip_comments("SELECT 'a -- b")).to eq("SELECT 'a -- b")
    end
  end

  describe ".rewrite_to_binds" do
    it "rewrites a code-position parameter to a positional placeholder" do
      sql, binds = described_class.rewrite_to_binds("SELECT :id", { "id" => 7 })

      expect(sql).to eq("SELECT $1")
      expect(binds).to eq([{ value: "7", type: 20 }])
    end

    it "reuses one placeholder and one bind for a repeated parameter" do
      sql, binds = described_class.rewrite_to_binds("SELECT :id, :id", { "id" => 7 })

      expect(sql).to eq("SELECT $1, $1")
      expect(binds.size).to eq(1)
    end

    it "expands a list parameter into a run of placeholders" do
      sql, binds = described_class.rewrite_to_binds("WHERE id IN (:ids)", { "ids" => [1, 2, 3] })

      expect(sql).to eq("WHERE id IN ($1, $2, $3)")
      expect(binds.map { |bind| bind[:value] }).to eq(%w[1 2 3])
    end

    it "leaves a marker inside a string literal untouched" do
      sql, binds = described_class.rewrite_to_binds("SELECT ':id'", { "id" => 7 })

      expect(sql).to eq("SELECT ':id'")
      expect(binds).to be_empty
    end

    it "ignores dollar-quote syntax that appears inside a string literal" do
      sql, binds = described_class.rewrite_to_binds("SELECT '$sql$:id$sql$'", { "id" => 7 })

      expect(sql).to eq("SELECT '$sql$:id$sql$'")
      expect(binds).to be_empty
    end

    it "rejects a parameter inside a dollar-quoted literal" do
      expect {
        described_class.rewrite_to_binds("SELECT $sql$:id$sql$", { "id" => 7 })
      }.to raise_error(
        DiscourseDataExplorer::ValidationError,
        "Parameters cannot be used inside dollar-quoted literals",
      )
    end
  end

  describe ".run_query" do
    fab!(:topic)

    it "should run a query that includes PG template patterns" do
      sql = <<~SQL
      WITH query AS (
        SELECT TO_CHAR(created_at, 'yyyy:mm:dd') AS date FROM topics
      ) SELECT * FROM query
      SQL

      query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)

      result = described_class.run_query(query)

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["date"]).to eq(topic.created_at.strftime("%Y:%m:%d"))
    end

    it "should run a query containing a question mark in the comment" do
      sql = <<~SQL
      WITH query AS (
        SELECT id FROM topics -- some SQL ? comment ?
      ) SELECT * FROM query
      SQL

      query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)

      result = described_class.run_query(query)

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["id"]).to eq(topic.id)
    end

    it "can run a query with params interpolation" do
      topic2 = Fabricate(:topic)

      sql = <<~SQL
      -- [params]
      -- int :topic_id = 99999999
      WITH query AS (
        SELECT
          id,
          TO_CHAR(created_at, 'yyyy:mm:dd') AS date
        FROM topics
        WHERE topics.id = :topic_id
      ) SELECT * FROM query
      SQL

      query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)

      result = described_class.run_query(query, { "topic_id" => topic2.id.to_s })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result].to_a.size).to eq(1)
      expect(result[:pg_result][0]["id"]).to eq(topic2.id)
    end

    it "runs a list parameter through an IN clause" do
      topic2 = Fabricate(:topic)
      topic3 = Fabricate(:topic)

      query = DiscourseDataExplorer::Query.create!(name: "list query", sql: <<~SQL)
            -- [params]
            -- int_list :ids
            SELECT id FROM topics WHERE id IN (:ids) ORDER BY id
          SQL

      result = described_class.run_query(query, { "ids" => "#{topic.id},#{topic3.id}" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result].to_a.map { |row| row["id"] }).to eq([topic.id, topic3.id].sort)
    end

    it "runs a query that checks a declared string parameter against IS NULL, with no cast needed" do
      query = DiscourseDataExplorer::Query.create!(name: "is null query", sql: <<~SQL)
            -- [params]
            -- string :site = hosted
            SELECT (:site) IS NULL AS is_null
          SQL

      result = described_class.run_query(query, { "site" => "hosted" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["is_null"]).to eq(false)
    end

    it "still compares a declared date parameter against a timestamp column with no cast" do
      query = DiscourseDataExplorer::Query.create!(name: "date compare query", sql: <<~SQL)
            -- [params]
            -- date :start_date
            SELECT id FROM topics WHERE created_at >= :start_date ORDER BY id
          SQL

      result = described_class.run_query(query, { "start_date" => "2020-01-01" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result].to_a.map { |row| row["id"] }).to include(topic.id)
    end

    it "rejects, without executing, a parameter inside a dollar-quoted literal" do
      query = DiscourseDataExplorer::Query.create!(name: "dollar query", sql: <<~SQL)
            -- [params]
            -- string :value
            SELECT $sql$:value$sql$ AS value
          SQL

      result = described_class.run_query(query, { "value" => "harmless$sql$) SELECT 1 --" })

      expect(result[:error]).to be_a(DiscourseDataExplorer::ValidationError)
      expect(result[:error].message).to eq(
        "Parameters cannot be used inside dollar-quoted literals",
      )
      expect(result[:pg_result]).to eq(nil)
    end

    it "adds query instrumentation after removing stored comments" do
      user = Fabricate(:user)
      query =
        DiscourseDataExplorer::Query.create!(
          name: "instrumented query",
          sql: "-- removable annotation\nSELECT current_query() AS sql",
        )

      result = described_class.run_query(query, {}, { current_user: user })
      executed_sql = result[:pg_result][0]["sql"]

      expect(result[:error]).to eq(nil)
      expect(executed_sql).to include(
        "DiscourseDataExplorer Query",
        "/admin/plugins/explorer/queries/#{query.id}",
        "Started by: #{user.username}",
      )
      expect(executed_sql).not_to include("removable annotation")
    end

    it "keeps comment markers that are part of a string literal" do
      query =
        DiscourseDataExplorer::Query.create!(
          name: "some query",
          sql: "SELECT '-- not /* a comment' AS value",
        )

      result = described_class.run_query(query)

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["value"]).to eq("-- not /* a comment")
    end

    it "interpolates each parameter once" do
      query = DiscourseDataExplorer::Query.create!(name: "parameterized query", sql: <<~SQL)
            -- [params]
            -- string :selected
            -- string :other
            SELECT :selected AS value
          SQL

      result =
        described_class.run_query(query, { "selected" => ":other", "other" => "other value" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["value"]).to eq(":other")
    end

    it "interpolates a parameter whose name is a prefix of another" do
      query = DiscourseDataExplorer::Query.create!(name: "parameterized query", sql: <<~SQL)
            -- [params]
            -- int :topic
            -- int :topic_id
            SELECT :topic AS a, :topic_id AS b
          SQL

      result = described_class.run_query(query, { "topic" => "1", "topic_id" => "2" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result].to_a).to eq([{ "a" => 1, "b" => 2 }])
    end

    it "leaves undeclared parameters alone" do
      query = DiscourseDataExplorer::Query.create!(name: "parameterized query", sql: <<~SQL)
            -- [params]
            -- string :declared
            SELECT :declared AS a, ':undeclared' AS b
          SQL

      result = described_class.run_query(query, { "declared" => "value" })

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result].to_a).to eq([{ "a" => "value", "b" => ":undeclared" }])
    end

    it "does not let a parameter break out of a string literal via another parameter" do
      query = DiscourseDataExplorer::Query.create!(name: "parameterized query", sql: <<~SQL)
            -- [params]
            -- string :selected
            -- string :other
            SELECT :selected AS value
          SQL

      result =
        described_class.run_query(
          query,
          {
            "selected" => "x:other",
            "other" => "'||(SELECT users.username FROM users LIMIT 1)||'",
          },
        )

      expect(result[:error]).to eq(nil)
      expect(result[:pg_result][0]["value"]).to eq("x:other")
    end

    describe "current_user_id parameter" do
      fab!(:user)

      it "injects the current user's id, ignoring user-provided values" do
        sql = <<~SQL
          -- [params]
          -- current_user_id :me
          SELECT id FROM users WHERE id = :me
        SQL

        query = DiscourseDataExplorer::Query.create!(name: "test", sql: sql)
        other_user = Fabricate(:user)

        result =
          described_class.run_query(query, { "me" => other_user.id.to_s }, { current_user: user })

        expect(result[:error]).to eq(nil)
        expect(result[:pg_result][0]["id"]).to eq(user.id)
      end

      it "returns an error when not nullable and no current user" do
        sql = <<~SQL
          -- [params]
          -- current_user_id :me
          SELECT id FROM users WHERE id = :me
        SQL

        query = DiscourseDataExplorer::Query.create!(name: "test", sql: sql)

        result = described_class.run_query(query, {}, {})

        expect(result[:error]).to be_a(DiscourseDataExplorer::ValidationError)
        expect(result[:error].message).to include("requires a logged in user")
      end

      it "allows null when nullable and no current user" do
        sql = <<~SQL
          -- [params]
          -- null current_user_id :me
          SELECT COALESCE(:me, -1) AS user_id
        SQL

        query = DiscourseDataExplorer::Query.create!(name: "test", sql: sql)

        result = described_class.run_query(query, {}, {})

        expect(result[:error]).to eq(nil)
        expect(result[:pg_result][0]["user_id"]).to eq(-1)
      end
    end

    describe ".add_extra_data" do
      it "treats any column with payload in the name as 'json'" do
        Fabricate(:reviewable_queued_post)
        sql = <<~SQL
          SELECT id, payload FROM reviewables LIMIT 10
        SQL
        query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)
        result = described_class.run_query(query)
        _, colrender = DiscourseDataExplorer::DataExplorer.add_extra_data(result[:pg_result])
        expect(colrender).to eq({ 1 => "json" })
      end

      it "treats columns with the actual json data type as 'json'" do
        ApiKeyScope.create(
          resource: "topics",
          action: "update",
          api_key_id: Fabricate(:api_key).id,
          allowed_parameters: {
            "category_id" => ["#{topic.category_id}"],
          },
        )
        sql = <<~SQL
          SELECT id, allowed_parameters FROM api_key_scopes LIMIT 10
        SQL
        query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)
        result = described_class.run_query(query)
        _, colrender = DiscourseDataExplorer::DataExplorer.add_extra_data(result[:pg_result])
        expect(colrender).to eq({ 1 => "json" })
      end

      describe "serializing models to serializer" do
        it "serializes correctly to BasicTopicSerializer for topic relations" do
          topic = Fabricate(:topic, locale: "ja")
          query = Fabricate(:query, sql: "SELECT id AS topic_id FROM topics WHERE id = #{topic.id}")

          pg_result = described_class.run_query(query)[:pg_result]
          relations, _ = DiscourseDataExplorer::DataExplorer.add_extra_data(pg_result)

          expect {
            records = relations[:topic].object
            records.map { |t| BasicTopicSerializer.new(t, root: false).as_json }
          }.not_to raise_error

          json = relations[:topic].as_json
          expect(json).to include(BasicTopicSerializer.new(topic, root: false).as_json)
        end

        it "chooses the correct serializer for tag_group" do
          tag_group = Fabricate(:tag_group)
          tag1 = Fabricate(:tag)
          tag2 = Fabricate(:tag)
          tag_group.tags = [tag1, tag2]

          query = Fabricate(:query, sql: "SELECT tag_id, tag_group_id FROM tag_group_memberships")

          pg_result = described_class.run_query(query)[:pg_result]
          relations, colrender = DiscourseDataExplorer::DataExplorer.add_extra_data(pg_result)

          expect(colrender).to eq({ 1 => :tag_group })
          expect(relations[:tag_group].as_json).to include(
            { "id" => tag_group.id, "name" => tag_group.name },
          )
        end
      end
    end
  end
end
