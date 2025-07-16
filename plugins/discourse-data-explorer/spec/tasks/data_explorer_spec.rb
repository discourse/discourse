# frozen_string_literal: true

require "rails_helper"

describe "Data Explorer rake tasks" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  def make_query(sql, opts = {}, group_ids = [])
    query =
      DiscourseDataExplorer::Query.create!(
        id: opts[:id],
        name: opts[:name] || "Query number",
        description: "A description for query number",
        sql: sql,
        hidden: opts[:hidden] || false,
      )
    group_ids.each { |group_id| query.query_groups.create!(group_id: group_id) }
    query
  end

  def hidden_queries
    DiscourseDataExplorer::Query.where(hidden: true).order(:id)
  end

  describe "data_explorer" do
    it "hides a single query" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A")
      make_query("SELECT 1 as value", id: 2, name: "B")
      # rake data_explorer[1] => hide query with ID 1
      silence_stdout { Rake::Task["data_explorer"].invoke(1) }

      # Soft deletion: PluginStoreRow should not be modified
      expect(DiscourseDataExplorer::Query.all.length).to eq(2)
      # Array of hidden queries should have exactly 1 element
      expect(hidden_queries.length).to eq(1)
      # That one element should have the same ID as the one invoked to be hidden
      expect(hidden_queries[0].id).to eq(1)
    end

    it "hides multiple queries" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A")
      make_query("SELECT 1 as value", id: 2, name: "B")
      make_query("SELECT 1 as value", id: 3, name: "C")
      make_query("SELECT 1 as value", id: 4, name: "D")
      # rake data_explorer[1,2,4] => hide queries with IDs 1, 2 and 4
      silence_stdout { Rake::Task["data_explorer"].invoke(1, 2, 4) }

      # Soft deletion: PluginStoreRow should not be modified
      expect(DiscourseDataExplorer::Query.all.length).to eq(4)
      # Array of hidden queries should have the same number of elements invoked to be hidden
      expect(hidden_queries.length).to eq(3)
      # The elements should have the same ID as the ones invoked to be hidden
      expect(hidden_queries[0].id).to eq(1)
      expect(hidden_queries[1].id).to eq(2)
      expect(hidden_queries[2].id).to eq(4)
    end

    context "when query does not exist in PluginStore" do
      it "should not hide the query" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", id: 1, name: "A")
        make_query("SELECT 1 as value", id: 2, name: "B")
        # rake data_explorer[3] => try to hide query with ID 3
        silence_stdout { Rake::Task["data_explorer"].invoke(3) }
        # rake data_explorer[3,4,5] => try to hide queries with IDs 3, 4 and 5
        silence_stdout { Rake::Task["data_explorer"].invoke(3, 4, 5) }

        # Array of hidden queries should be empty
        expect(hidden_queries.length).to eq(0)
      end
    end
  end

  describe "#unhide_query" do
    it "unhides a single query" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
      make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
      # rake data_explorer:unhide_query[1] => unhide query with ID 1
      silence_stdout { Rake::Task["data_explorer:unhide_query"].invoke(1) }

      # Soft deletion: PluginStoreRow should not be modified
      expect(DiscourseDataExplorer::Query.all.length).to eq(2)
      # Array of hidden queries should have exactly 1 element
      expect(hidden_queries.length).to eq(1)
      # There should be one remaining element that is still hidden
      expect(hidden_queries[0].id).to eq(2)
    end

    it "unhides multiple queries" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
      make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
      make_query("SELECT 1 as value", id: 3, name: "C", hidden: true)
      make_query("SELECT 1 as value", id: 4, name: "D", hidden: true)
      # rake data_explorer:unhide_query[1,2,4] => unhide queries with IDs 1, 2 and 4
      silence_stdout { Rake::Task["data_explorer:unhide_query"].invoke(1, 2, 4) }

      # Soft deletion: PluginStoreRow should not be modified
      expect(DiscourseDataExplorer::Query.all.length).to eq(4)
      # Array of hidden queries should have exactly 1 element
      expect(hidden_queries.length).to eq(1)
      # There should be one remaining element that is still hidden
      expect(hidden_queries[0].id).to eq(3)
    end

    context "when query does not exist in PluginStore" do
      it "should not unhide the query" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
        make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
        # rake data_explorer:unhide_query[3] => try to unhide query with ID 3
        silence_stdout { Rake::Task["data_explorer:unhide_query"].invoke(3) }
        # rake data_explorer:unhide_query[3,4,5] => try to unhide queries with IDs 3, 4 and 5
        silence_stdout { Rake::Task["data_explorer:unhide_query"].invoke(3, 4, 5) }

        # Array of hidden queries shouldn't change
        expect(hidden_queries.length).to eq(2)
      end
    end
  end

  describe "#hard_delete" do
    it "hard deletes a single query" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
      make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
      # rake data_explorer:hard_delete[1] => hard delete query with ID 1
      silence_stdout { Rake::Task["data_explorer:hard_delete"].invoke(1) }

      # Hard deletion: query list should be shorter by 1
      expect(DiscourseDataExplorer::Query.all.length).to eq(1)
      # Array of hidden queries should have exactly 1 element
      expect(hidden_queries.length).to eq(1)
      # There should be one remaining hidden element
      expect(hidden_queries[0].id).to eq(2)
    end

    it "hard deletes multiple queries" do
      DiscourseDataExplorer::Query.destroy_all
      make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
      make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
      make_query("SELECT 1 as value", id: 3, name: "C", hidden: true)
      make_query("SELECT 1 as value", id: 4, name: "D", hidden: true)
      # rake data_explorer:hard_delete[1,2,4] => hard delete queries with IDs 1, 2 and 4
      silence_stdout { Rake::Task["data_explorer:hard_delete"].invoke(1, 2, 4) }

      # Hard deletion: query list should be shorter by 3
      expect(DiscourseDataExplorer::Query.all.length).to eq(1)
      # Array of hidden queries should have exactly 1 element
      expect(hidden_queries.length).to eq(1)
      # There should be one remaining hidden element
      expect(hidden_queries[0].id).to eq(3)
    end

    context "when query does not exist in PluginStore" do
      it "should not hard delete the query" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", id: 1, name: "A", hidden: true)
        make_query("SELECT 1 as value", id: 2, name: "B", hidden: true)
        # rake data_explorer:hard_delete[3] => try to hard delete query with ID 3
        silence_stdout { Rake::Task["data_explorer:hard_delete"].invoke(3) }
        # rake data_explorer:hard_delete[3,4,5] => try to hard delete queries with IDs 3, 4 and 5
        silence_stdout { Rake::Task["data_explorer:hard_delete"].invoke(3, 4, 5) }

        # Array of hidden queries shouldn't change
        expect(hidden_queries.length).to eq(2)
      end
    end

    context "when query is not hidden" do
      it "should not hard delete the query" do
        DiscourseDataExplorer::Query.destroy_all
        make_query("SELECT 1 as value", id: 1, name: "A")
        # rake data_explorer:hard_delete[1] => try to hard delete query with ID 1
        silence_stdout { Rake::Task["data_explorer:hard_delete"].invoke(1) }

        # List of queries shouldn't change
        expect(DiscourseDataExplorer::Query.all.length).to eq(1)
      end
    end
  end
end
