# frozen_string_literal: true

describe DiscourseDataExplorer::ResultToMarkdown do
  fab!(:user)
  fab!(:post)
  fab!(:query) { DiscourseDataExplorer::Query.find(-1) }

  let(:query_params) { [{ from_days_ago: 0 }, { duration_days: 15 }] }
  let(:query_result) { DiscourseDataExplorer::DataExplorer.run_query(query, query_params) }

  before { SiteSetting.data_explorer_enabled = true }

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
  end
end
