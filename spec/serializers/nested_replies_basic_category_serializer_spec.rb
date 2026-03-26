# frozen_string_literal: true

RSpec.describe CategorySerializer do
  fab!(:category)
  fab!(:admin)

  before { SiteSetting.nested_replies_enabled = true }

  it "serializes nested_replies_default as true when category setting is set" do
    category.category_setting.update!(nested_replies_default: true)
    cat = Category.includes(:category_setting).find(category.id)

    json = CategorySerializer.new(cat, scope: Guardian.new(admin), root: false).as_json

    expect(json[:category_setting][:nested_replies_default]).to eq(true)
  end

  it "serializes nested_replies_default as false when not set" do
    cat = Category.includes(:category_setting).find(category.id)

    json = CategorySerializer.new(cat, scope: Guardian.new(admin), root: false).as_json

    expect(json[:category_setting][:nested_replies_default]).to eq(false)
  end
end
