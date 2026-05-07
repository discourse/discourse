# frozen_string_literal: true

describe CategoriesController do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:admin) { Fabricate(:user, admin: true) }

  before do
    SiteSetting.topic_voting_enabled = true
    sign_in(admin)
  end

  it "enables voting correctly" do
    put "/categories/#{category.id}.json",
        params: {
          custom_fields: {
            "enable_topic_voting" => true,
          },
        }

    expect(Category.can_vote?(category.id)).to eq(true)
  end

  it "does not recreate database record" do
    category_setting = DiscourseTopicVoting::CategorySetting.create!(category: category)

    put "/categories/#{category.id}.json",
        params: {
          custom_fields: {
            "enable_topic_voting" => true,
          },
        }
    expect(DiscourseTopicVoting::CategorySetting.last.id).to eq(category_setting.id)
  end

  it "disables voting correctly" do
    put "/categories/#{category.id}.json",
        params: {
          custom_fields: {
            "enable_topic_voting" => false,
          },
        }
    expect(Category.can_vote?(category.id)).to eq(false)
  end

  it "works fine when `custom_fields` isn't passed " do
    put "/categories/#{category.id}.json", params: { hello: "world" }
    expect(response.status).to eq(200)
  end

  describe "#update" do
    before do
      Category.reset_voting_cache
      SiteSetting.enable_simplified_category_creation = true
      SiteSetting.enable_ideas_category_type_setup = true
    end

    after do
      SiteSetting.enable_simplified_category_creation = false
      SiteSetting.enable_ideas_category_type_setup = false
    end

    it "can add the ideas type to the category" do
      expect(Category.can_vote?(category.id)).to eq(false)

      put "/categories/#{category.id}.json", params: { category_types: ["ideas"] }

      expect(response.status).to eq(200)
      cat_json = response.parsed_body["category"]
      expect(cat_json["category_types"].keys).to include("ideas", "discussion")

      expect(category.reload.category_types.keys).to include(:ideas)
      expect(category.reload.category_types.keys).to include(:discussion)
      expect(Category.can_vote?(category.id)).to eq(true)
    end

    it "can remove the ideas type from the category" do
      Categories::Configure.call(
        guardian: admin.guardian,
        params: {
          category_type: "ideas",
          category_id: category.id,
        },
      )

      expect(Category.can_vote?(category.id)).to eq(true)
      put "/categories/#{category.id}.json", params: { category_types: [] }

      expect(response.status).to eq(200)
      cat_json = response.parsed_body["category"]
      expect(cat_json["category_types"].keys).not_to include("ideas")
      expect(cat_json["category_types"].keys).to include("discussion")

      expect(category.reload.category_types.keys).not_to include(:ideas)
      expect(category.reload.category_types.keys).to include(:discussion)
      expect(Category.can_vote?(category.id)).to eq(false)
    end
  end
end
