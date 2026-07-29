# frozen_string_literal: true

require_relative "../support/query_id_repair_fixture"

describe "fix query ids rake task" do
  subject(:run_task) { Rake::Task["data_explorer:fix_query_ids"].invoke }

  before do
    Rake::Task.clear
    silence_warnings { Discourse::Application.load_tasks }
  end

  let(:query_name) { "Awesome query" }
  let(:query_id_repair_fixture) { QueryIdRepairFixture.new }

  it "fixes the ID of the query if they share the same name" do
    original_query_id = 4
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: original_query_id)
    query_id_repair_fixture.create_query(name: query_name)

    run_task

    expect(query_id_repair_fixture.find_query(name: query_name).id).to eq(original_query_id)
  end

  it "only fixes queries with unique name" do
    original_query_id = 4
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: original_query_id)
    query_id_repair_fixture.create_query(name: query_name)
    query_id_repair_fixture.create_query(name: query_name)

    run_task

    expect(query_id_repair_fixture.find_query(name: query_name).id).not_to eq(original_query_id)
  end

  it "skips queries that already have the same ID" do
    db_query = query_id_repair_fixture.create_query(name: query_name)
    last_updated_at = db_query.updated_at
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: db_query.id)

    run_task

    expect(query_id_repair_fixture.find_query(name: query_name).updated_at).to eq_time(
      last_updated_at,
    )
  end

  it "keeps queries the rest of the queries" do
    original_query_id = 4
    different_query_name = "Another query"
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: original_query_id)
    query_id_repair_fixture.create_query(name: query_name)
    query_id_repair_fixture.create_query(name: different_query_name)

    run_task

    expect(query_id_repair_fixture.find_query(name: different_query_name)).not_to be_nil
  end

  it "works even if they are additional conflicts" do
    different_query_name = "Another query"
    additional_conflict = query_id_repair_fixture.create_query(name: different_query_name)
    query_id_repair_fixture.create_query(name: query_name)
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: additional_conflict.id)

    run_task

    expect(query_id_repair_fixture.find_query(name: different_query_name).id).not_to eq(
      additional_conflict.id,
    )
    expect(query_id_repair_fixture.find_query(name: query_name).id).to eq(additional_conflict.id)
  end

  describe "query groups" do
    let(:group) { Fabricate(:group) }

    it "fixes the query group's query_id" do
      original_query_id = 4
      query_id_repair_fixture.create_query(name: query_name, group_ids: [group.id])
      query_id_repair_fixture.create_plugin_store_row(
        name: query_name,
        id: original_query_id,
        group_ids: [group.id],
      )

      run_task

      expect(query_id_repair_fixture.find_query_group(query_id: original_query_id)).not_to be_nil
    end

    it "works with additional conflicts" do
      different_query_name = "Another query"
      additional_conflict =
        query_id_repair_fixture.create_query(name: different_query_name, group_ids: [group.id])
      query_id_repair_fixture.create_query(name: query_name, group_ids: [group.id])
      query_id_repair_fixture.create_plugin_store_row(
        name: query_name,
        id: additional_conflict.id,
        group_ids: [group.id],
      )

      run_task

      conflict = query_id_repair_fixture.find_query(name: different_query_name).query_groups.first
      fixed = query_id_repair_fixture.find_query_group(query_id: additional_conflict.id)

      expect(conflict.query_id).not_to eq(additional_conflict.id)
      expect(fixed.query_id).to eq(additional_conflict.id)
    end
  end

  it "changes the serial sequence for future queries" do
    original_query_id = 4
    query_id_repair_fixture.create_plugin_store_row(name: query_name, id: original_query_id)
    query_id_repair_fixture.create_query(name: query_name)

    run_task
    post_fix_query = query_id_repair_fixture.create_query(name: query_name)

    expect(post_fix_query.id).to eq(original_query_id + 1)
  end
end
