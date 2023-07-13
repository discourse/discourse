# frozen_string_literal: true

RSpec.describe DirectoryColumnsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  describe "#index" do
    it "returns all active directory columns" do
      likes_given = DirectoryColumn.find_by(name: "likes_given")
      likes_given.update(enabled: false)

      get "/directory-columns.json"

      expect(response.parsed_body["directory_columns"].map { |dc| dc["name"] }).not_to include(
        "likes_given",
      )
    end
  end
end
