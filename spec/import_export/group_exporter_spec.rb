# frozen_string_literal: true

require "rails_helper"
require "import_export/group_exporter"

describe ImportExport::GroupExporter do

  before do
    STDOUT.stubs(:write)
  end

  it 'export all the groups' do
    group = Fabricate(:group)
    data = ImportExport::GroupExporter.new.perform.export_data

    expect(data[:groups].count).to eq(1)
    expect(data[:users].blank?).to eq(true)
  end

  it 'export groups with users' do\
    group = Fabricate(:group)
    user = Fabricate(:user)
    group_user = Fabricate(:group_user, group: group, user: user)
    data = ImportExport::GroupExporter.new(true).perform.export_data

    expect(data[:groups].count).to eq(1)
    expect(data[:users].count).to eq(1)
  end

end
