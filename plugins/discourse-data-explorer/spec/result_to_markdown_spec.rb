# frozen_string_literal: true

describe DiscourseDataExplorer::ResultToMarkdown do
  fab!(:user)
  fab!(:post)
  fab!(:query) { DiscourseDataExplorer::Query.find(-1) }

  let(:query_params) { [{ from_days_ago: 0 }, { duration_days: 15 }] }
  let(:query_result) { DiscourseDataExplorer::DataExplorer.run_query(query, query_params) }

  before { SiteSetting.data_explorer_enabled = true }

  def run(sql)
    query = DiscourseDataExplorer::Query.new(sql:)
    DiscourseDataExplorer::DataExplorer.run_query(query, {})[:pg_result]
  end

  describe ".convert" do
    it "format results as a markdown table with headers and columns" do
      result = described_class.convert(query_result[:pg_result])

      table = <<~MD
        | liker_user | liked_user | count |
        | :----- | :----- | :----- |
      MD

      expect(result).to include(table)
    end

    it "enriches result data within the table rows" do
      PostActionCreator.new(user, post, PostActionType.types[:like]).perform
      result = described_class.convert(query_result[:pg_result])

      expect(result).to include(
        "| #{user.username} (#{user.id}) | #{post.user.username} (#{post.user.id}) | 1 |\n",
      )
    end

    it "renders url columns as links only when render_url_columns is set" do
      pg_result =
        run(
          "SELECT '3,https://test.com' AS some_url, NULL AS null_url, 3 AS int_url, true AS bool_url",
        )

      expect(described_class.convert(pg_result, render_url_columns: false)).to include(
        "| 3,https://test.com |  | 3 | true |\n",
      )
      expect(described_class.convert(pg_result, render_url_columns: true)).to include(
        "| [3](https://test.com) |  | [3](3) | [true](true) |\n",
      )
    end

    it "labels post columns with the author's username and strips only the _id suffix" do
      pg_result = run("SELECT #{post.id} AS post_id, 1 AS user_id_count")

      result = described_class.convert(pg_result)

      expect(result).to include("| post | user_id_count |\n")
      expect(result).to include("| #{post.user.username} (#{post.id}) | 1 |\n")
    end

    it "loads each relation once" do
      pg_result = run("SELECT id AS user_id FROM users")

      queries = track_sql_queries { described_class.convert(pg_result) }

      expect(queries.count { |sql| sql.include?('FROM "users"') }).to eq(1)
    end

    it "escapes pipes and collapses newlines in cells" do
      pg_result = run("SELECT E'a|b\\nc' AS data")

      expect(described_class.convert(pg_result)).to include("| a\\|b c |\n")
    end

    it "sanitizes cells that contain html" do
      pg_result = run("SELECT '<script>x</script>a & b %7Bc%7D' AS data")

      expect(described_class.convert(pg_result)).to include("| xa & b {c} |\n")
    end
  end
end
