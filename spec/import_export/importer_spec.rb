require "rails_helper"
require "import_export/category_exporter"
require "import_export/category_structure_exporter"
require "import_export/importer"

describe ImportExport::Importer do

  before do
    STDOUT.stubs(:write)
  end

  let(:import_data) do
    import_file = Rack::Test::UploadedFile.new(file_from_fixtures("import-export.json", "json"))
    data = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(import_file.read))
  end

  def import(data)
    ImportExport::Importer.new(data).perform
  end

  context '.perform' do

    it 'topics and users' do
      data = import_data.dup
      data[:categories] = nil
      data[:groups] = nil

      expect {
        import(data)
      }.to change { Category.count }.by(0)
        .and change { Group.count }.by(0)
        .and change { Topic.count }.by(2)
        .and change { User.count }.by(2)
    end

    it 'categories and groups' do
      data = import_data.dup
      data[:topics] = nil
      data[:users] = nil

      expect {
        import(data)
      }.to change { Category.count }.by(6)
        .and change { Group.count }.by(2)
        .and change { Topic.count }.by(6)
        .and change { User.count }.by(0)
    end

    it 'categories, groups and users' do
      data = import_data.dup
      data[:topics] = nil

      expect {
        import(data)
      }.to change { Category.count }.by(6)
        .and change { Group.count }.by(2)
        .and change { Topic.count }.by(6)
        .and change { User.count }.by(2)
    end

    it 'all' do
      expect {
        import(import_data)
      }.to change { Category.count }.by(6)
        .and change { Group.count }.by(2)
        .and change { Topic.count }.by(8)
        .and change { User.count }.by(2)
    end

  end

end
