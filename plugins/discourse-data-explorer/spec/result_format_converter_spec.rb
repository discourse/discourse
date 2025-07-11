# frozen_string_literal: true

describe DiscourseDataExplorer::ResultFormatConverter do
  fab!(:user)
  fab!(:post)
  fab!(:query) { DiscourseDataExplorer::Query.find(-1) }

  let(:query_params) { [{ from_days_ago: 0 }, { duration_days: 15 }] }
  let(:query_result) { DiscourseDataExplorer::DataExplorer.run_query(query, query_params) }

  before { SiteSetting.data_explorer_enabled = true }

  describe ".convert" do
    context "for csv files" do
      it "format results as a csv table with headers and columns" do
        result = described_class.convert(:csv, query_result)

        table = <<~CSV
          liker_user_id,liked_user_id,count
        CSV

        expect(result).to include(table)
      end
    end

    context "for json files" do
      it "format results as a json file" do
        result = described_class.convert(:json, query_result, { query_params: })

        expect(result[:columns]).to contain_exactly("liker_user_id", "liked_user_id", "count")
        expect(result[:params]).to eq(query_params)
      end
    end
  end
end
