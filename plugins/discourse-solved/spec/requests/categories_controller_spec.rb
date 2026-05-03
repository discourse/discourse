# frozen_string_literal: true

RSpec.describe CategoriesController do
  fab!(:category)
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.enable_simplified_category_creation = true
    SiteSetting.enable_support_category_type_setup = true
  end

  describe "#update" do
    it "can add the support type to the category" do
      expect(category.enable_accepted_answers?).to eq(false)

      put "/categories/#{category.id}.json", params: { category_types: ["support"] }

      expect(response.status).to eq(200)
      cat_json = response.parsed_body["category"]
      expect(cat_json["category_types"].keys).to include("support", "discussion")

      expect(category.reload.category_types.keys).to include(:support)
      expect(category.reload.category_types.keys).to include(:discussion)
      expect(category.enable_accepted_answers?).to eq(true)
    end

    it "can remove the support type from the category" do
      Categories::Configure.call(
        guardian: admin.guardian,
        params: {
          category_type: "support",
          category_id: category.id,
        },
      )

      expect(category.enable_accepted_answers?).to eq(true)
      put "/categories/#{category.id}.json", params: { category_types: [] }

      expect(response.status).to eq(200)
      cat_json = response.parsed_body["category"]
      expect(cat_json["category_types"].keys).not_to include("support")
      expect(cat_json["category_types"].keys).to include("discussion")

      expect(category.reload.category_types.keys).not_to include(:support)
      expect(category.reload.category_types.keys).to include(:discussion)
      expect(category.enable_accepted_answers?).to eq(false)
    end
  end
end
