# frozen_string_literal: true

describe GroupTagNotificationDefault do
  describe ".resolve_tag_ids" do
    it "returns an empty selection without querying tags" do
      queries = track_sql_queries { expect(described_class.resolve_tag_ids([])).to eq([]) }

      expect(queries).to be_empty
    end
  end
end
