# frozen_string_literal: true

require 'rails_helper'

describe FreedomPatches::SchemaMigrationDetails do

  # we usually don't really need this model so lets not clutter up with it
  class SchemaMigrationDetail < ActiveRecord::Base
  end

  class TestMigration < ActiveRecord::Migration[4.2]
    def up
      sleep 0.001
    end
  end

  it "logs information on migration" do
    migration = TestMigration.new("awesome_migration", "20110225050318")

    ActiveRecord::Base.connection_pool.with_connection do |conn|
      migration.exec_migration(conn, :up)
    end

    info = SchemaMigrationDetail.find_by(version: "20110225050318")

    expect(info.duration).to be > 0
    expect(info.git_version).to eq Discourse.git_version
    expect(info.direction).to eq "up"
    expect(info.rails_version).to eq Rails.version
    expect(info.name).to eq "awesome_migration"
  end
end
