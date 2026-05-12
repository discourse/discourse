# frozen_string_literal: true

describe DiscourseDataExplorer::QueryController do
  def response_json
    response.parsed_body
  end

  before { SiteSetting.data_explorer_enabled = true }

  def make_query(sql, opts = {}, group_ids = [])
    query =
      DiscourseDataExplorer::Query.create!(
        name: opts[:name] || "Query number",
        description: "A description for query number",
        sql: sql,
        hidden: opts[:hidden] || false,
      )
    group_ids.each { |group_id| query.query_groups.create!(group_id: group_id) }
    query
  end

  describe "Admin" do
    fab!(:admin)

    before { sign_in(admin) }

    describe "when disabled" do
      before { SiteSetting.data_explorer_enabled = false }

      it "denies every request" do
        get "/admin/plugins/discourse-data-explorer/queries.json"
        expect(response.status).to eq(404)

        get "/admin/plugins/discourse-data-explorer/schema.json"
        expect(response.status).to eq(404)

        get "/admin/plugins/discourse-data-explorer/queries/3.json"
        expect(response.status).to eq(404)

        post "/admin/plugins/discourse-data-explorer/queries.json", params: { id: 3 }
        expect(response.status).to eq(404)

        post "/admin/plugins/discourse-data-explorer/queries/3/run.json"
        expect(response.status).to eq(404)

        put "/admin/plugins/discourse-data-explorer/queries/3.json"
        expect(response.status).to eq(404)

        delete "/admin/plugins/discourse-data-explorer/queries/3.json"
        expect(response.status).to eq(404)
      end
    end

    describe "#index" do
      it "behaves nicely with no user created queries" do
        DiscourseDataExplorer::Query.destroy_all
        get "/admin/plugins/discourse-data-explorer/queries.json"
        expect(response.status).to eq(200)
        expect(response_json["queries"].count).to eq(DiscourseDataExplorer::Queries.default.count)
      end

      it "shows all available queries sorted by name when requested" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", name: "B")
        make_query("SELECT 1 as value", name: "A")
        get "/admin/plugins/discourse-data-explorer/queries.json",
            params: {
              order: "name",
              ascending: "true",
            }
        expect(response.status).to eq(200)
        expect(response_json["queries"].length).to eq(
          DiscourseDataExplorer::Queries.default.count + 2,
        )
        expect(response_json["queries"][0]["name"]).to eq("A")
        expect(response_json["queries"][1]["name"]).to eq("B")
      end

      it "doesn't show hidden/deleted queries" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", name: "A", hidden: false)
        make_query("SELECT 1 as value", name: "B", hidden: true)
        make_query("SELECT 1 as value", name: "C", hidden: true)
        get "/admin/plugins/discourse-data-explorer/queries.json"
        expect(response.status).to eq(200)
        expect(response_json["queries"].length).to eq(
          DiscourseDataExplorer::Queries.default.count + 1,
        )
      end

      it "merges default query data with persisted last_run_at and groups" do
        freeze_time

        post "/admin/plugins/discourse-data-explorer/queries/-1/run.json"
        expect(response.status).to eq(200)

        # Run persists the default query in the local DB; update it to assert index merges it
        group = Fabricate(:group)
        persisted = DiscourseDataExplorer::Query.find_by(id: -1)
        persisted.update!(last_run_at: 3.days.ago, groups: [group])

        get "/admin/plugins/discourse-data-explorer/queries.json"
        expect(response.status).to eq(200)

        expect(response_json["queries"].count).to eq(DiscourseDataExplorer::Queries.default.count)
        default_in_response = response_json["queries"].find { |q| q["id"] == -1 }
        expect(default_in_response).to be_present
        expect(Time.parse(default_in_response["last_run_at"])).to eq_time(3.days.ago)
        expect(default_in_response["group_ids"]).to eq([group.id])
      end

      it "doesn't show double-ups of default queries" do
        post "/admin/plugins/discourse-data-explorer/queries/-1/run.json"
        expect(response.status).to eq(200)

        get "/admin/plugins/discourse-data-explorer/queries.json"
        expect(response.status).to eq(200)
        expect(response_json["queries"].count).to eq(DiscourseDataExplorer::Queries.default.count)
      end
    end

    describe "#update" do
      fab!(:user2, :user)
      fab!(:group2) { Fabricate(:group, users: [user2]) }

      it "allows group to access system query" do
        query = DiscourseDataExplorer::Query.find(-4)
        put "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              "query" => {
                "name" => query.name,
                "description" => query.description,
                "sql" => query.sql,
                "user_id" => query.user_id,
                "created_at" => query.created_at,
                "group_ids" => [group2.id],
                "last_run_at" => query.last_run_at,
              },
              "id" => query.id,
            }

        expect(response.status).to eq(200)
      end

      it "returns a proper json error for invalid updates" do
        query = DiscourseDataExplorer::Query.find(-4)
        put "/admin/plugins/discourse-data-explorer/queries/#{query.id}",
            params: {
              "query" => {
                "name" => "",
              },
              "id" => query.id,
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(["Name can't be blank"])
      end
    end

    describe "#destroy" do
      it "returns 404 when query does not exist" do
        delete "/admin/plugins/discourse-data-explorer/queries/999999.json"
        expect(response.status).to eq(404)
      end

      it "hides the query" do
        query = make_query("SELECT 1 as value")

        delete "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json"

        expect(response.status).to eq(200)
        expect(query.reload.hidden).to eq(true)
      end
    end

    describe "#run" do
      def run_query(id, params = {}, explain = false)
        params = Hash[params.map { |a| [a[0], a[1].to_s] }]
        post "/admin/plugins/discourse-data-explorer/queries/#{id}/run.json",
             params: {
               params: params.to_json,
               explain: explain,
             }
      end

      it "can run queries" do
        query = make_query("SELECT 23 as my_value")
        run_query query.id
        expect(response.status).to eq(200)
        expect(response_json["success"]).to eq(true)
        expect(response_json["errors"]).to eq([])
        expect(response_json["columns"]).to eq(["my_value"])
        expect(response_json["rows"]).to eq([[23]])
        expect(response_json["explain"]).to be_nil
      end

      it "can run and explain queries" do
        query = make_query("SELECT 23 as my_value")
        run_query query.id, {}, true
        expect(response.status).to eq(200)
        expect(response_json["success"]).to eq(true)
        expect(response_json["errors"]).to eq([])
        expect(response_json["columns"]).to eq(["my_value"])
        expect(response_json["rows"]).to eq([[23]])
        expect(response_json["explain"]).to match("Result ")
      end

      it "can process parameters" do
        query = make_query <<~SQL
        -- [params]
        -- int :foo = 34
        SELECT :foo as my_value
        SQL

        run_query query.id, foo: 23
        expect(response.status).to eq(200)
        expect(response_json["errors"]).to eq([])
        expect(response_json["success"]).to eq(true)
        expect(response_json["columns"]).to eq(["my_value"])
        expect(response_json["rows"]).to eq([[23]])

        run_query query.id
        expect(response.status).to eq(200)
        expect(response_json["errors"]).to eq([])
        expect(response_json["success"]).to eq(true)
        expect(response_json["columns"]).to eq(["my_value"])
        expect(response_json["rows"]).to eq([[34]])

        # 2.3 is not an integer
        run_query query.id, foo: "2.3"
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/ValidationError/)
      end

      it "can accept parameters as a hash instead of JSON string" do
        query = make_query <<~SQL
        -- [params]
        -- int :foo = 34
        -- string :bar = 'default'
        SELECT :foo as my_value, :bar as text_value
        SQL

        # Test with hash format
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               params: {
                 foo: 42,
                 bar: "test",
               },
             },
             as: :json
        expect(response.status).to eq(200)
        expect(response_json["success"]).to eq(true)
        expect(response_json["columns"]).to eq(%w[my_value text_value])
        expect(response_json["rows"]).to eq([[42, "test"]])
      end

      it "can accept empty hash for parameters" do
        query = make_query "SELECT 23 as my_value"

        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               params: {
               },
             }
        expect(response.status).to eq(200)
        expect(response_json["success"]).to eq(true)
        expect(response_json["columns"]).to eq(["my_value"])
        expect(response_json["rows"]).to eq([[23]])
      end

      context "when rate limited" do
        def unlimited_request(query_id, headers = {})
          post "/admin/plugins/discourse-data-explorer/queries/#{query_id}/run.json",
               params: {
                 params: {}.to_json,
               },
               headers: headers

          expect(response.status).to eq(200)
        end

        def limited_request(query_id, headers = {})
          post "/admin/plugins/discourse-data-explorer/queries/#{query_id}/run.json",
               params: {
                 params: {}.to_json,
               },
               headers: headers

          expect(response.status).to eq(429)
          expect(response.parsed_body["extras"]).to eq(
            { "wait_seconds" => 9, "time_left" => "9 seconds" },
          )
        end

        before { RateLimiter.enable }

        it "limits query runs from API when using block mode" do
          global_setting :max_data_explorer_api_reqs_per_10_seconds, 1
          global_setting :max_data_explorer_api_req_mode, "block"

          admin = Fabricate(:admin)
          api_key = Fabricate(:api_key, user: admin)

          query = make_query("SELECT 23 as my_value")

          headers = { HTTP_API_KEY: api_key.key, HTTP_API_USERNAME: admin.username }

          now = Time.now
          freeze_time(now)

          unlimited_request(query.id, headers)

          freeze_time(now + 1.second)

          limited_request(query.id, headers)

          freeze_time(now + 10.seconds)

          unlimited_request(query.id, headers)
        end

        it "does not limit query runs from API when using warn mode" do
          global_setting :max_data_explorer_api_reqs_per_10_seconds, 1
          global_setting :max_data_explorer_api_req_mode, "warn"

          admin = Fabricate(:admin)
          api_key = Fabricate(:api_key, user: admin)

          query = make_query("SELECT 23 as my_value")

          headers = { HTTP_API_KEY: api_key.key, HTTP_API_USERNAME: admin.username }

          freeze_time

          unlimited_request(query.id, headers)

          Discourse.expects(:warn).once

          unlimited_request(query.id, headers)
        end

        it "does not limit query runs from UI" do
          global_setting :max_data_explorer_api_reqs_per_10_seconds, 1
          global_setting :max_data_explorer_api_req_mode, "block"

          query = make_query("SELECT 23 as my_value")

          freeze_time

          unlimited_request(query.id)
          unlimited_request(query.id)
        end
      end

      it "doesn't allow you to modify the database #1" do
        p = create_post

        query = make_query <<~SQL
        UPDATE posts SET cooked = '<p>you may already be a winner!</p>' WHERE id = #{p.id}
        RETURNING id
        SQL

        run_query query.id
        p.reload

        # Manual Test - comment out the following lines:
        #   DB.exec "SET TRANSACTION READ ONLY"
        #   raise ActiveRecord::Rollback
        # This test should fail on the below check.
        expect(p.cooked).to_not match(/winner/)
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/read-only transaction/)
      end

      it "doesn't allow you to modify the database #2" do
        p = create_post

        query = make_query <<~SQL
          SELECT 1
        )
        SELECT * FROM query;
        RELEASE SAVEPOINT active_record_1;
        SET TRANSACTION READ WRITE;
        UPDATE posts SET cooked = '<p>you may already be a winner!</p>' WHERE id = #{p.id};
        SAVEPOINT active_record_1;
        SET TRANSACTION READ ONLY;
        WITH query AS (
          SELECT 1
        SQL

        run_query query.id
        p.reload

        # Manual Test - change out the following line:
        #
        #  module DiscourseDataExplorer
        #   def self.run_query(...)
        #     if query.sql =~ /;/
        #
        # to
        #
        #     if false && query.sql =~ /;/
        #
        # Afterwards, this test should fail on the below check.
        expect(p.cooked).to_not match(/winner/)
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/semicolon/)
      end

      it "doesn't allow you to lock rows" do
        query = make_query <<~SQL
        SELECT id FROM posts FOR UPDATE
        SQL

        run_query query.id
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/read-only transaction/)
      end

      it "doesn't allow you to create a table" do
        query = make_query <<~SQL
        CREATE TABLE mytable (id serial)
        SQL

        run_query query.id
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/read-only transaction|syntax error/)
      end

      it "doesn't allow you to break the transaction" do
        query = make_query <<~SQL
        COMMIT
        SQL

        run_query query.id
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/syntax error/)

        query.sql = <<~SQL
        )
        SQL

        run_query query.id
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/syntax error/)

        query.sql = <<~SQL
        RELEASE SAVEPOINT active_record_1
        SQL

        run_query query.id
        expect(response.status).to eq(422)
        expect(response_json["errors"]).to_not eq([])
        expect(response_json["success"]).to eq(false)
        expect(response_json["errors"].first).to match(/syntax error/)
      end

      it "can export data in CSV format" do
        query = make_query("SELECT 23 as my_value")
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               download: 1,
             }
        expect(response.status).to eq(200)
      end

      context "with the `limit` parameter" do
        before do
          create_post
          create_post
          create_post
        end

        it "should limit the results in JSON response" do
          SiteSetting.data_explorer_query_result_limit = 2
          query = make_query <<~SQL
            SELECT id FROM posts
          SQL

          run_query query.id
          expect(response_json["rows"].count).to eq(2)

          post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
               params: {
                 limit: 1,
               }
          expect(response_json["rows"].count).to eq(1)

          post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
               params: {
                 limit: DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT + 1,
               }
          expect(response.status).to eq(400)
        end

        it "should limit the results in CSV download" do
          query = make_query <<~SQL
            SELECT id FROM posts
          SQL

          stub_const(DiscourseDataExplorer, "QUERY_RESULT_MAX_LIMIT", 2) do
            post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.csv",
                 params: {
                   download: 1,
                 }
            expect(response.body.split("\n").count).to eq(3)

            post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.csv",
                 params: {
                   download: 1,
                   limit: 1,
                 }
            expect(response.body.split("\n").count).to eq(2)

            post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.csv",
                 params: {
                   download: 1,
                   limit: DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT + 1,
                 }
            expect(response.body.split("\n").count).to eq(3)
          end
        end
      end
    end

    describe "result caching" do
      def run_query(id, params = {})
        params = Hash[params.map { |a| [a[0], a[1].to_s] }]
        post "/admin/plugins/discourse-data-explorer/queries/#{id}/run.json",
             params: {
               params: params.to_json,
             }
      end

      it "caches results after running a query" do
        query = make_query("SELECT 23 as my_value")

        run_query query.id
        expect(response.status).to eq(200)

        cached = DiscourseDataExplorer::QueryRunner.cached_result(query, nil)
        expect(cached).to be_present
        expect(cached["rows"]).to eq([[23]])
      end

      it "returns cached results in show response" do
        query = make_query("SELECT 23 as my_value")
        run_query query.id

        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json"
        expect(response.status).to eq(200)
        expect(response_json["query"]["cached_result"]).to be_present
        expect(response_json["query"]["cached_result"]["rows"]).to eq([[23]])
        expect(response_json["query"]["cached_result"]["cached_at"]).to be_present
      end

      it "returns no cached_result on cache miss" do
        query = make_query("SELECT 1")
        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json"
        expect(response.status).to eq(200)
        expect(response_json["query"]["cached_result"]).to be_nil
      end

      it "uses URL params for cache lookup" do
        query = make_query("-- [params]\n-- int :val = 1\n\nSELECT :val as my_value")

        run_query query.id, val: 5
        run_query query.id, val: 10

        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              params: { val: "5" }.to_json,
            }
        expect(response_json["query"]["cached_result"]["rows"]).to eq([[5]])

        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              params: { val: "10" }.to_json,
            }
        expect(response_json["query"]["cached_result"]["rows"]).to eq([[10]])
      end

      it "does not cache results with explain" do
        query = make_query("SELECT 1")
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               explain: "true",
             }
        expect(response.status).to eq(200)

        cached = DiscourseDataExplorer::QueryRunner.cached_result(query, nil)
        expect(cached).to be_nil
      end

      it "does not cache queries with internal params" do
        query = make_query("-- [params]\n-- current_user_id :me\n\nSELECT :me as user_id")

        run_query query.id
        expect(response.status).to eq(200)

        cached = DiscourseDataExplorer::QueryRunner.cached_result(query, nil)
        expect(cached).to be_nil
      end

      it "invalidates cache when SQL changes" do
        query = make_query("SELECT 1 as old_value")
        run_query query.id

        expect(DiscourseDataExplorer::QueryRunner.cached_result(query, nil)).to be_present

        put "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              query: {
                name: query.name,
                sql: "SELECT 2 as new_value",
                group_ids: [],
              },
            }
        expect(response.status).to eq(200)

        expect(DiscourseDataExplorer::QueryRunner.cached_result(query, nil)).to be_nil
      end

      it "does not invalidate cache when only name changes" do
        query = make_query("SELECT 1")
        run_query query.id

        put "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              query: {
                name: "New name",
                sql: query.sql,
                group_ids: [],
              },
            }
        expect(response.status).to eq(200)

        expect(DiscourseDataExplorer::QueryRunner.cached_result(query, nil)).to be_present
      end

      it "returns cached result on reload when run with no explicit params" do
        query = make_query("-- [params]\n-- int :val = 1\n\nSELECT :val as my_value")

        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json"
        expect(response.status).to eq(200)

        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json"
        expect(response_json["query"]["cached_result"]).to be_present
      end

      it "does not cache results when a non-default limit is used" do
        query = make_query("SELECT 1")
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               limit: 1,
             }
        expect(response.status).to eq(200)

        cached = DiscourseDataExplorer::QueryRunner.cached_result(query, nil)
        expect(cached).to be_nil
      end

      it "handles malformed params in show without error" do
        query = make_query("SELECT 1")
        get "/admin/plugins/discourse-data-explorer/queries/#{query.id}.json",
            params: {
              params: "not-valid-json",
            }
        expect(response.status).to eq(200)
        expect(response_json["query"]["id"]).to eq(query.id)
      end

      it "rejects malformed params in run" do
        query = make_query("SELECT 1")
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               params: "not-valid-json",
             }
        expect(response.status).to eq(422)
      end

      it "rejects malformed params in download" do
        query = make_query("SELECT 1")
        post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json",
             params: {
               download: 1,
               params: "not-valid-json",
             }
        expect(response.status).to eq(422)
      end
    end
  end

  describe "Non-Admin" do
    fab!(:user)
    fab!(:group) { Fabricate(:group, users: [user]) }

    before { sign_in(user) }

    describe "when disabled" do
      before { SiteSetting.data_explorer_enabled = false }

      it "denies every request" do
        get "/g/1/reports.json"
        expect(response.status).to eq(404)

        get "/g/1/reports/1.json"
        expect(response.status).to eq(404)

        post "/g/1/reports/1/run.json"
        expect(response.status).to eq(404)
      end
    end

    it "cannot access admin endpoints" do
      query = make_query("SELECT 1 as value")
      post "/admin/plugins/discourse-data-explorer/queries/#{query.id}/run.json"
      expect(response.status).to eq(403)
    end

    describe "#group_reports_index" do
      it "only returns queries that the group has access to" do
        group.add(user)
        make_query("SELECT 1 as value", { name: "A" }, ["#{group.id}"])

        get "/g/#{group.name}/reports.json"
        expect(response.status).to eq(200)
        expect(response_json["queries"].length).to eq(1)
        expect(response_json["queries"][0]["name"]).to eq("A")
      end

      it "returns a 404 when the user should not have access to the query " do
        other_user = Fabricate(:user)
        sign_in(other_user)

        get "/g/#{group.name}/reports.json"
        expect(response.status).to eq(404)
      end

      it "return a 200 when the user has access the the query" do
        group.add(user)

        get "/g/#{group.name}/reports.json"
        expect(response.status).to eq(200)
      end

      it "does not return hidden queries" do
        group.add(user)
        make_query("SELECT 1 as value", { name: "A", hidden: true }, ["#{group.id}"])
        make_query("SELECT 1 as value", { name: "B" }, ["#{group.id}"])

        get "/g/#{group.name}/reports.json"
        expect(response.status).to eq(200)
        expect(response_json["queries"].length).to eq(1)
        expect(response_json["queries"][0]["name"]).to eq("B")
      end
    end

    describe "#group_reports_run" do
      it "runs the query" do
        query = make_query("SELECT 1828 as value", { name: "B" }, ["#{group.id}"])

        post "/g/#{group.name}/reports/#{query.id}/run.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)
        expect(response.parsed_body["columns"]).to eq(["value"])
        expect(response.parsed_body["rows"]).to eq([[1828]])
      end

      it "does not include post relations the user cannot see" do
        private_post =
          Fabricate(
            :private_message_post,
            raw: "Ssshh! This hidden data explorer excerpt must not leak.",
          )
        visible_post = Fabricate(:post, raw: "Visible data explorer excerpt may render.")
        guardian = user.guardian
        expect(guardian.can_see_post?(private_post)).to eq(false)
        expect(guardian.can_see_post?(visible_post)).to eq(true)

        query_sql = <<~SQL
          SELECT #{private_post.id} AS post_id
          UNION ALL
          SELECT #{visible_post.id} AS post_id
        SQL
        query = make_query(query_sql, { name: "Posts" }, [group.id.to_s])

        post "/g/#{group.name}/reports/#{query.id}/run.json"

        expect(response.status).to eq(200)
        post_relations = response.parsed_body["relations"]["post"]
        expect(post_relations).to contain_exactly(include("id" => visible_post.id))
        expect(response.body).to include(visible_post.raw)
        expect(response.body).not_to include(private_post.raw)
      end

      it "does not include topic relations the user cannot see" do
        private_topic =
          Fabricate(
            :private_message_topic,
            title: "Ssshh this hidden data explorer topic must not leak",
          )
        visible_topic = Fabricate(:topic, title: "Visible data explorer topic may render")
        guardian = user.guardian
        expect(guardian.can_see_topic?(private_topic)).to eq(false)
        expect(guardian.can_see_topic?(visible_topic)).to eq(true)

        query_sql = <<~SQL
          SELECT #{private_topic.id} AS topic_id
          UNION ALL
          SELECT #{visible_topic.id} AS topic_id
        SQL
        query = make_query(query_sql, { name: "Topics" }, [group.id.to_s])

        post "/g/#{group.name}/reports/#{query.id}/run.json"

        expect(response.status).to eq(200)
        topic_relations = response.parsed_body["relations"]["topic"]
        expect(topic_relations).to contain_exactly(include("id" => visible_topic.id))
        expect(response.body).to include(visible_topic.title)
        expect(response.body).not_to include(private_topic.title)
      end

      it "can accept parameters as a hash" do
        query_string = <<~SQL
        -- [params]
        -- int :num = 100
        SELECT :num as value
        SQL
        query = make_query(query_string, { name: "Parameterized Query" }, ["#{group.id}"])

        post "/g/#{group.name}/reports/#{query.id}/run.json", params: { params: { num: 999 } }
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)
        expect(response.parsed_body["columns"]).to eq(["value"])
        expect(response.parsed_body["rows"]).to eq([[999]])
      end

      it "returns a 404 when the user should not have access to the query " do
        group.add(user)
        query = make_query("SELECT 1 as value", {}, [])

        post "/g/#{group.name}/reports/#{query.id}/run.json"
        expect(response.status).to eq(404)
      end

      it "return a 200 when the user has access the the query" do
        group.add(user)
        query = make_query("SELECT 1 as value", {}, [group.id.to_s])

        post "/g/#{group.name}/reports/#{query.id}/run.json"
        expect(response.status).to eq(200)
      end

      it "return a 404 when the query is hidden" do
        group.add(user)
        query = make_query("SELECT 1 as value", { hidden: true }, [group.id.to_s])

        post "/g/#{group.name}/reports/#{query.id}/run.json"
        expect(response.status).to eq(404)
      end
    end

    describe "#group_reports_show" do
      it "returns a 404 when the user should not have access to the query " do
        query = make_query("SELECT 1 as value", {}, [])

        get "/g/#{group.name}/reports/#{query.id}.json"
        expect(response.status).to eq(404)
      end

      it "return a 200 when the user has access the the query" do
        query = make_query("SELECT 1 as value", {}, [group.id.to_s])

        get "/g/#{group.name}/reports/#{query.id}.json"
        expect(response.status).to eq(200)
      end

      it "return a 404 when the query is hidden" do
        query = make_query("SELECT 1 as value", { hidden: true }, [group.id.to_s])

        get "/g/#{group.name}/reports/#{query.id}.json"
        expect(response.status).to eq(404)
      end
    end

    describe "GET /data-explorer/queries/:id/run.json (public_run)" do
      it "runs the query for a user with access" do
        group.add(user)
        query = make_query("SELECT 1828 as value", { name: "B" }, [group.id.to_s])

        get "/data-explorer/queries/#{query.id}/run.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)
        expect(response.parsed_body["columns"]).to eq(["value"])
        expect(response.parsed_body["rows"]).to eq([[1828]])
      end

      it "returns 404 when the user does not have access" do
        # query restricted to another group, user is not a member
        other_group = Fabricate(:group)
        query = make_query("SELECT 1 as value", {}, [other_group.id.to_s])

        get "/data-explorer/queries/#{query.id}/run.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 when the query is hidden" do
        group.add(user)
        query = make_query("SELECT 1 as value", { hidden: true }, [group.id.to_s])

        get "/data-explorer/queries/#{query.id}/run.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 when the query has no group assignments" do
        query = make_query("SELECT 1 as value", {}, [])

        get "/data-explorer/queries/#{query.id}/run.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "legacy /admin/plugins/explorer/ routes" do
    fab!(:admin)

    before { sign_in(admin) }

    it "redirects GET /admin/plugins/explorer/queries to /admin/plugins/discourse-data-explorer/queries" do
      get "/admin/plugins/explorer/queries"
      expect(response).to redirect_to("/admin/plugins/discourse-data-explorer/queries")
    end

    it "redirects GET /admin/plugins/explorer/queries/:id to /admin/plugins/discourse-data-explorer/queries/:id" do
      query = make_query("SELECT 1 as value")
      get "/admin/plugins/explorer/queries/#{query.id}"
      expect(response).to redirect_to("/admin/plugins/discourse-data-explorer/queries/#{query.id}")
    end

    it "serves GET /admin/plugins/explorer/schema.json" do
      get "/admin/plugins/explorer/schema.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to be_a(Hash)
      expect(response.parsed_body.keys).to include("posts")
    end

    it "serves GET /admin/plugins/explorer/groups.json" do
      get "/admin/plugins/explorer/groups.json"
      expect(response.status).to eq(200)
    end

    it "serves POST /admin/plugins/explorer/queries.json" do
      post "/admin/plugins/explorer/queries.json",
           params: {
             query: {
               name: "Legacy route test",
               description: "Testing legacy route",
               sql: "SELECT 1",
             },
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["query"]["name"]).to eq("Legacy route test")
    end

    it "serves PUT /admin/plugins/explorer/queries/:id.json" do
      query = make_query("SELECT 1 as value")
      put "/admin/plugins/explorer/queries/#{query.id}.json",
          params: {
            query: {
              name: "Updated via legacy route",
              sql: query.sql,
            },
          }
      expect(response.status).to eq(200)
      expect(query.reload.name).to eq("Updated via legacy route")
    end

    it "serves DELETE /admin/plugins/explorer/queries/:id.json" do
      query = make_query("SELECT 1 as value")
      delete "/admin/plugins/explorer/queries/#{query.id}.json"
      expect(response.status).to eq(200)
      expect(query.reload.hidden).to eq(true)
    end

    it "serves POST /admin/plugins/explorer/queries/:id/run.json" do
      query = make_query("SELECT 42 as legacy_value")
      post "/admin/plugins/explorer/queries/#{query.id}/run.json", params: { params: {}.to_json }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["columns"]).to eq(["legacy_value"])
      expect(response.parsed_body["rows"]).to eq([[42]])
    end

    it "serves POST /admin/plugins/explorer/queries/:id/run without .json suffix or Accept header" do
      query = make_query("SELECT 42 as legacy_value")
      post "/admin/plugins/explorer/queries/#{query.id}/run",
           params: {
             params: {}.to_json,
           },
           headers: {
             "Accept" => "",
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["columns"]).to eq(["legacy_value"])
      expect(response.parsed_body["rows"]).to eq([[42]])
    end
  end

  describe "Admin" do
    fab!(:admin)

    before do
      sign_in(admin)
      SiteSetting.data_explorer_enabled = true
    end

    describe "#generate_with_ai" do
      before { SiteSetting.data_explorer_ai_queries_enabled = true }

      it "returns 404 when AI queries are disabled" do
        SiteSetting.data_explorer_ai_queries_enabled = false
        post "/admin/plugins/discourse-data-explorer/queries/generate.json",
             params: {
               ai_description: "show me users",
             }
        expect(response.status).to eq(404)
      end

      it "requires ai_description parameter" do
        post "/admin/plugins/discourse-data-explorer/queries/generate.json"
        expect(response.status).to eq(400)
      end

      it "rejects ai_description over 2000 characters" do
        post "/admin/plugins/discourse-data-explorer/queries/generate.json",
             params: {
               ai_description: "a" * 2001,
             }
        expect(response.status).to eq(400)
      end

      it "enqueues a generation job and returns generation_id" do
        post "/admin/plugins/discourse-data-explorer/queries/generate.json",
             params: {
               ai_description: "show me users",
             }

        expect(response.status).to eq(200)
        json = response.parsed_body
        generation_id = json["generation_id"]
        expect(generation_id).to be_present
        expect(json["status"]).to eq("generating")

        job = Jobs::GenerateDeQueryWithAi.jobs.last
        expect(job["args"].first["generation_id"]).to eq(generation_id)
        expect(job["args"].first["user_id"]).to eq(admin.id)
        expect(job["args"].first["ai_description"]).to eq("show me users")
      end

      it "passes existing_sql when provided" do
        post "/admin/plugins/discourse-data-explorer/queries/generate.json",
             params: {
               ai_description: "refine this query",
               existing_sql: "SELECT 1",
             }

        expect(response.status).to eq(200)

        job = Jobs::GenerateDeQueryWithAi.jobs.last
        expect(job["args"].first["existing_sql"]).to eq("SELECT 1")
      end

      it "rate limits requests" do
        RateLimiter.enable

        11.times do
          post "/admin/plugins/discourse-data-explorer/queries/generate.json",
               params: {
                 ai_description: "show me users",
               }
        end

        expect(response.status).to eq(429)
      end
    end
  end
end
