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
end
