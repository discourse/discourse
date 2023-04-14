# frozen_string_literal: true

require "import_export/group_exporter"

RSpec.describe ImportExport::GroupExporter do
  before { STDOUT.stubs(:write) }

  it "exports all the groups" do
    group = Fabricate(:group)
    user = Fabricate(:user)
    group_user = Fabricate(:group_user, group: group, user: user)
    data = ImportExport::GroupExporter.new.perform.export_data

    expect(data[:groups].map { |g| g[:id] }).to include(group.id)
    expect(data[:users].blank?).to eq(true)
  end

  it "exports all the groups with users" do
    group = Fabricate(:group)
    user = Fabricate(:user)
    group_user = Fabricate(:group_user, group: group, user: user)
    data = ImportExport::GroupExporter.new(true).perform.export_data

    expect(data[:groups].map { |g| g[:id] }).to include(group.id)
    expect(data[:users].map { |u| u[:id] }).to include(user.id)
  end
end
