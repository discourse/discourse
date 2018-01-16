require "rails_helper"
require "import_export/topic_exporter"

describe ImportExport::TopicExporter do

  before do
    STDOUT.stubs(:write)
  end

  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let!(:post) { Fabricate(:post, topic: topic, user: user) }

  context '.perform' do
    it 'export a single topic' do
      data = ImportExport::TopicExporter.new([topic.id]).perform.export_data

      expect(data[:categories].blank?).to eq(true)
      expect(data[:groups].blank?).to eq(true)
      expect(data[:topics].count).to eq(1)
      expect(data[:users].count).to eq(1)
    end

    it 'export multiple topics' do
      topic2 = Fabricate(:topic, user: user)
      post2 = Fabricate(:post, user: user, topic: topic2)
      data = ImportExport::TopicExporter.new([topic.id, topic2.id]).perform.export_data

      expect(data[:categories].blank?).to eq(true)
      expect(data[:groups].blank?).to eq(true)
      expect(data[:topics].count).to eq(2)
      expect(data[:users].map { |u| u[:id] }).to match_array([user.id])
    end
  end

end
