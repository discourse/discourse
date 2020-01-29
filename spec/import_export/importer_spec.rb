# frozen_string_literal: true

require "rails_helper"
require "import_export"

describe ImportExport::Importer do

  before do
    STDOUT.stubs(:write)
  end

  let(:import_data) do
    import_file = Rack::Test::UploadedFile.new(file_from_fixtures("import-export.json", "json"))
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(import_file.read))
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

    context 'categories and groups' do
      it 'works' do
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

      it 'works with sub-sub-categories' do
        data = import_data.dup

        # 11 -> 10 -> 15
        data[:categories].find { |c| c[:id] == 10 }[:parent_category_id] = 11
        data[:categories].find { |c| c[:id] == 15 }[:parent_category_id] = 10

        expect { import(data) }
          .to change { Category.count }.by(6)
          .and change { SiteSetting.max_category_nesting }.from(2).to(3)
      end

      it 'fixes permissions' do
        data = import_data.dup
        data[:categories].find { |c| c[:id] == 10 }[:permissions_params] = { custom_group: 1 }
        data[:categories].find { |c| c[:id] == 15 }[:permissions_params] = { staff: 1 }

        permissions = data[:categories].find { |c| c[:id] == 10 }[:permissions_params]

        expect { import(data) }
          .to change { Category.count }.by(6)
          .and change { permissions[:staff] }.from(nil).to(1)
      end
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
