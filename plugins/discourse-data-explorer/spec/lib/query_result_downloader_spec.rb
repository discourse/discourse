# frozen_string_literal: true

describe DiscourseDataExplorer::QueryResultDownloader do
  fab!(:admin)
  fab!(:query) do
    Fabricate(
      :query,
      sql:
        "SELECT 1 AS id, 'tomtom' AS name UNION ALL SELECT 2, 'steak' UNION ALL SELECT 3, 'zorro'",
      user: admin,
    )
  end

  describe ".download" do
    it "returns JSON results" do
      result = described_class.download(query, nil, current_user: admin, format: :json)

      expect(result[:error]).to be_nil
      expect(result[:format]).to eq(:json)
      expect(result[:data][:columns]).to eq(%w[id name])
      expect(result[:data][:rows]).to eq([[1, "tomtom"], [2, "steak"], [3, "zorro"]])
    end

    it "returns CSV results" do
      result = described_class.download(query, nil, current_user: admin, format: :csv)

      expect(result[:error]).to be_nil
      expect(result[:format]).to eq(:csv)

      rows = result[:data].split("\n")
      expect(rows[0]).to eq("id,name")
      expect(rows[1]).to eq("1,tomtom")
      expect(rows[2]).to eq("2,steak")
      expect(rows[3]).to eq("3,zorro")
    end

    it "returns error for invalid queries" do
      bad_query = Fabricate(:query, sql: "SELECT * FROM nonexistent_table_xyz")
      result = described_class.download(bad_query, nil, current_user: admin)

      expect(result[:error]).to be_present
    end
  end
end
