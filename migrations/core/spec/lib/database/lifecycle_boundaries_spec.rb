# frozen_string_literal: true

require "prism"

RSpec.describe Migrations::Database::Lifecycle do
  it "confines native connection construction and raw worker forks to their owners" do
    root = File.join(Migrations.host_app_root, "migrations")
    native_owners = {
      "PG" => "core/lib/migrations/database/drivers/postgres.rb",
      "PG::Connection" => "core/lib/migrations/database/drivers/postgres.rb",
      "Extralite::Database" => "core/lib/migrations/database/drivers/sqlite.rb",
      "SQLite3::Database" => nil,
      "Mysql2::Client" => nil,
      "Trilogy" => nil,
    }
    constructors = %i[new connect open connect_start async_connect sync_connect setdb setdblogin]
    violations = []

    Dir[File.join(root, "**", "*.rb")].each do |path|
      relative = path.delete_prefix("#{root}/")
      next if relative.include?("/spec/")
      nodes = [Prism.parse_file(path).value]
      until nodes.empty?
        node = nodes.pop
        nodes.concat(node.compact_child_nodes)
        next unless node.is_a?(Prism::CallNode)
        receiver = node.receiver&.location&.slice&.gsub(/\s/, "")&.delete_prefix("::")
        if constructors.include?(node.name) && native_owners.key?(receiver)
          next if relative == native_owners[receiver]
          violations << "#{relative}:#{node.location.start_line}: use ManagedConnection and a reviewed driver"
        elsif %i[fork _fork].include?(node.name) && [nil, "Process", "Kernel"].include?(receiver)
          next if relative == "core/lib/migrations/common/fork_manager.rb"
          violations << "#{relative}:#{node.location.start_line}: use ForkManager.fork"
        end
      end
    end

    expect(violations).to eq([])
  end
end
