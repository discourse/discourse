# frozen_string_literal: true

require "import_export"

RSpec.describe ImportExport::CategoryExporter do
  fab!(:category)
  fab!(:group)
  fab!(:user)
  fab!(:user2, :user)
  fab!(:user3, :user)

  before { STDOUT.stubs(:write) }

  describe ".perform" do
    it "export the category when it is found" do
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(0)
    end

    it "export the category with permission groups" do
      _category_group = Fabricate(:category_group, category: category, group: group)
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(1)
    end

    it "export multiple categories" do
      category2 = Fabricate(:category)
      _category_group = Fabricate(:category_group, category: category, group: group)
      data = ImportExport::CategoryExporter.new([category.id, category2.id]).perform.export_data

      expect(data[:categories].count).to eq(2)
      expect(data[:groups].count).to eq(1)
    end

    it "export the category with topics and users" do
      topic1 = Fabricate(:topic, category: category, user_id: -1)
      Fabricate(:post, topic: topic1, user: User.find(-1), post_number: 1)
      topic2 = Fabricate(:topic, category: category, user: user)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      _reply1 = Fabricate(:post, topic: topic2, user: user2, post_number: 2)
      _reply2 = Fabricate(:post, topic: topic2, user: user3, post_number: 3)
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(0)
      expect(data[:topics].count).to eq(2)
      expect(data[:users].map { |u| u[:id] }).to match_array([user.id, user2.id, user3.id])
    end
  end
end
