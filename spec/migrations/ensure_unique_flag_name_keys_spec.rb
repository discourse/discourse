# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260624140945_ensure_unique_flag_name_keys.rb")

RSpec.describe EnsureUniqueFlagNameKeys do
  subject(:migrate) { described_class.new.up }

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  it "disambiguates duplicate name_keys and enforces uniqueness" do
    flag1 = Fabricate(:flag, name: "alpha")
    flag2 = Fabricate(:flag, name: "beta")
    flag3 = Fabricate(:flag, name: "gamma")

    ActiveRecord::Base.connection.remove_index(:flags, :name_key, if_exists: true)
    Flag.unscoped.where(id: [flag1.id, flag2.id, flag3.id]).update_all(name_key: "custom_")

    migrate

    keys = Flag.unscoped.where(id: [flag1.id, flag2.id, flag3.id]).order(:id).pluck(:name_key)

    expect(keys.first).to eq("custom_")
    expect(keys[1]).to eq("custom__#{flag2.id}")
    expect(keys[2]).to eq("custom__#{flag3.id}")
    expect(keys.uniq.size).to eq(3)

    expect(ActiveRecord::Base.connection.index_exists?(:flags, :name_key, unique: true)).to eq(true)
  end

  it "leaves already-unique name_keys untouched" do
    flag = Fabricate(:flag, name: "unique flag")
    original = flag.name_key

    migrate

    expect(flag.reload.name_key).to eq(original)
  end
end
