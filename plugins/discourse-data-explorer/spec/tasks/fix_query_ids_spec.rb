# frozen_string_literal: true

require "rails_helper"

describe "fix query ids rake task" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  let(:query_name) { "Awesome query" }

  it "fixes the ID of the query if they share the same name" do
    original_query_id = 4
    create_plugin_store_row(query_name, original_query_id)
    create_query(query_name)

    run_task

    expect(find(query_name).id).to eq(original_query_id)
  end

  it "only fixes queries with unique name" do
    original_query_id = 4
    create_plugin_store_row(query_name, original_query_id)
    create_query(query_name)
    create_query(query_name)

    run_task

    expect(find(query_name).id).not_to eq(original_query_id)
  end

  it "skips queries that already have the same ID" do
    db_query = create_query(query_name)
    last_updated_at = db_query.updated_at
    create_plugin_store_row(query_name, db_query.id)

    run_task

    expect(find(query_name).updated_at).to eq_time(last_updated_at)
  end

  it "keeps queries the rest of the queries" do
    original_query_id = 4
    different_query_name = "Another query"
    create_plugin_store_row(query_name, original_query_id)
    create_query(query_name)
    create_query(different_query_name)

    run_task

    expect(find(different_query_name)).not_to be_nil
  end

  it "works even if they are additional conflicts" do
    different_query_name = "Another query"
    additional_conflict = create_query(different_query_name)
    create_query(query_name)
    create_plugin_store_row(query_name, additional_conflict.id)

    run_task

    expect(find(different_query_name).id).not_to eq(additional_conflict.id)
    expect(find(query_name).id).to eq(additional_conflict.id)
  end

  describe "query groups" do
    let(:group) { Fabricate(:group) }

    it "fixes the query group's query_id" do
      original_query_id = 4
      create_query(query_name, [group.id])
      create_plugin_store_row(query_name, original_query_id, [group.id])

      run_task

      expect(find_query_group(original_query_id)).not_to be_nil
    end

    it "works with additional conflicts" do
      different_query_name = "Another query"
      additional_conflict = create_query(different_query_name, [group.id])
      create_query(query_name, [group.id])
      create_plugin_store_row(query_name, additional_conflict.id, [group.id])

      run_task

      conflict = find(different_query_name).query_groups.first
      fixed = find_query_group(additional_conflict.id)

      expect(conflict.query_id).not_to eq(additional_conflict.id)
      expect(fixed.query_id).to eq(additional_conflict.id)
    end

    def find_query_group(id)
      DiscourseDataExplorer::QueryGroup.find_by(query_id: id)
    end
  end

  it "changes the serial sequence for future queries" do
    original_query_id = 4
    create_plugin_store_row(query_name, original_query_id)
    create_query(query_name)

    run_task
    post_fix_query = create_query(query_name)

    expect(post_fix_query.id).to eq(original_query_id + 1)
  end

  def run_task
    Rake::Task["data_explorer:fix_query_ids"].invoke
  end

  def create_plugin_store_row(name, id, group_ids = [])
    key = "q:#{id}"

    PluginStore.set(
      DiscourseDataExplorer::PLUGIN_NAME,
      key,
      attributes(name).merge(group_ids: group_ids, id: id),
    )
  end

  def create_query(name, group_ids = [])
    DiscourseDataExplorer::Query
      .create!(attributes(name))
      .tap { |query| group_ids.each { |group_id| query.query_groups.create!(group_id: group_id) } }
  end

  def attributes(name)
    {
      id:
        DiscourseDataExplorer::Query.count == 0 ? 5 : DiscourseDataExplorer::Query.maximum(:id) + 1,
      name: name,
      description: "A Query",
      sql: "SELECT 1",
      created_at: 3.hours.ago,
      last_run_at: 1.hour.ago,
      hidden: false,
    }
  end

  def find(name)
    DiscourseDataExplorer::Query.find_by(name: name)
  end
end
