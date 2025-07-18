# frozen_string_literal: true

describe DiscourseDataExplorer::DataExplorer do
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
