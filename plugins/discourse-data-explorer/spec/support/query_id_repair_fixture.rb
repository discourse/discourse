# frozen_string_literal: true

class QueryIdRepairFixture
  def create_plugin_store_row(name:, id:, group_ids: [])
    PluginStore.set(
      DiscourseDataExplorer::PLUGIN_NAME,
      "q:#{id}",
      attributes(name:).merge(group_ids:, id:),
    )
  end

  def create_query(name:, group_ids: [])
    DiscourseDataExplorer::Query
      .create!(attributes(name:))
      .tap { |query| group_ids.each { |group_id| query.query_groups.create!(group_id:) } }
  end

  def find_query(name:)
    DiscourseDataExplorer::Query.find_by(name:)
  end

  def find_query_group(query_id:)
    DiscourseDataExplorer::QueryGroup.find_by(query_id:)
  end

  private

  def attributes(name:)
    {
      id:
        DiscourseDataExplorer::Query.count == 0 ? 5 : DiscourseDataExplorer::Query.maximum(:id) + 1,
      name:,
      description: "A Query",
      sql: "SELECT 1",
      created_at: 3.hours.ago,
      last_run_at: 1.hour.ago,
      hidden: false,
    }
  end
end
