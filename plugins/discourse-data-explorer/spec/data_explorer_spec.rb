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
        "/admin/plugins/discourse-data-explorer/queries/#{query.id}",
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

      it "treats columns with the actual json or jsonb data type as 'json'" do
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

      it "treats jsonb columns as 'json'" do
        query =
          DiscourseDataExplorer::Query.create!(
            name: "some query",
            sql: "SELECT '[{\"key\": \"value\"}]'::jsonb AS response_format",
          )
        result = described_class.run_query(query)

        _, colrender = DiscourseDataExplorer::DataExplorer.add_extra_data(result[:pg_result])

        expect(colrender).to eq({ 0 => "json" })
      end

      it "treats json and jsonb array columns as 'json'" do
        query = DiscourseDataExplorer::Query.create!(name: "some query", sql: <<~SQL)
              SELECT
                ARRAY['{\"key\": \"value\"}'::json] AS json_values,
                ARRAY['{\"key\": \"value\"}'::jsonb] AS jsonb_values
            SQL
        result = described_class.run_query(query)

        _, colrender = DiscourseDataExplorer::DataExplorer.add_extra_data(result[:pg_result])

        expect(colrender).to eq({ 0 => "json", 1 => "json" })
      end

      it "limits relation resolution to the query result limit per relation type" do
        SiteSetting.data_explorer_query_result_limit = 2
        topics = Fabricate.times(4, :topic)
        query = DiscourseDataExplorer::Query.create!(name: "some query", sql: <<~SQL)
              SELECT #{topics[0].id} AS topic_id, #{topics[2].id} AS related_topic_id
              UNION ALL
              SELECT #{topics[1].id} AS topic_id, #{topics[3].id} AS related_topic_id
            SQL

        pg_result = described_class.run_query(query)[:pg_result]
        relations, _ = DiscourseDataExplorer::DataExplorer.add_extra_data(pg_result)

        expect(relations[:topic].as_json.size).to eq(2)
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
