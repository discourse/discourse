# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260820092502_convert_site_contact_group_name_to_id.rb")

RSpec.describe ConvertSiteContactGroupNameToId do
  subject(:migrate) { described_class.new.up }

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  def store(value)
    SiteSetting.create!(
      name: "site_contact_group_name",
      value:,
      data_type: SiteSetting.types[:group],
    )
  end

  def stored
    SiteSetting.find_by(name: "site_contact_group_name").value
  end

  it "converts a group name to its id regardless of case" do
    group = Fabricate(:group, name: "support")
    store("SUPPORT")

    migrate

    expect(stored).to eq(group.id.to_s)
  end

  it "leaves an id alone even when a group is named after it" do
    group = Fabricate(:group, id: 12_345)
    Fabricate(:group, name: group.id.to_s)
    store(group.id.to_s)

    migrate

    expect(stored).to eq(group.id.to_s)
  end
end
