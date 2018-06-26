require "rails_helper"
require "import_export/category_exporter"

describe ImportExport::CategoryExporter do

  let(:category) { Fabricate(:category) }
  let(:group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }

  before do
    STDOUT.stubs(:write)
  end

  context '.perform' do
    it 'export the category when it is found' do
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(0)
    end

    it 'export the category with permission groups' do
      category_group = Fabricate(:category_group, category: category, group: group)
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(1)
    end

    it 'export multiple categories' do
      category2 = Fabricate(:category)
      category_group = Fabricate(:category_group, category: category, group: group)
      data = ImportExport::CategoryExporter.new([category.id, category2.id]).perform.export_data

      expect(data[:categories].count).to eq(2)
      expect(data[:groups].count).to eq(1)
    end

    it 'export the category with topics and users' do
      topic1 = Fabricate(:topic, category: category, user_id: -1)
      Fabricate(:post, topic: topic1, user: User.find(-1), post_number: 1)
      topic2 = Fabricate(:topic, category: category, user: user)
      Fabricate(:post, topic: topic2, user: user, post_number: 1)
      reply1 = Fabricate(:post, topic: topic2, user: user2, post_number: 2)
      reply2 = Fabricate(:post, topic: topic2, user: user3, post_number: 3)
      data = ImportExport::CategoryExporter.new([category.id]).perform.export_data

      expect(data[:categories].count).to eq(1)
      expect(data[:groups].count).to eq(0)
      expect(data[:topics].count).to eq(2)
      expect(data[:users].map { |u| u[:id] }).to match_array([user.id, user2.id, user3.id])
    end
  end

end
