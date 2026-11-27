# frozen_string_literal: true

require "pg"
require_relative "../../../../script/bulk_import/discourse_merger/inventory"

RSpec.describe BulkImport::DiscourseMerge::Inventory do
  let(:inventory) { described_class.new(nil) }
  let(:connection) { instance_double(PG::Connection) }
  let(:counts) do
    {
      "chat_channels" => 8,
      "chat_messages" => 0,
      "chat_thread_custom_fields" => 0,
      "chat_threads" => 1,
      "user_chat_thread_memberships" => 2,
    }
  end

  def capture_plugin_inventory
    tables = instance_double(PG::Result, column_values: counts.keys)
    allow(connection).to receive(:exec).with(
      /FROM pg_tables.*user_chat_thread_memberships/m,
    ).and_return(tables)
    counts.each do |table, count|
      result = instance_double(PG::Result)
      allow(result).to receive(:getvalue).with(0, 0).and_return(count.to_s)
      allow(connection).to receive(:exec).with("SELECT count(*) FROM \"#{table}\"").and_return(
        result,
      )
    end
    inventory.send(:plugin_inventory, connection)
  end

  def stub_thread_title(exists)
    result = instance_double(PG::Result)
    allow(result).to receive(:getvalue).with(0, 0).and_return(exists ? "t" : "f")
    allow(connection).to receive(:exec).with(/SELECT EXISTS .*FROM chat_threads/).and_return(result)
  end

  it "reports orphaned untitled threads and memberships as omitted when there are no messages" do
    stub_thread_title(false)

    result = capture_plugin_inventory

    expect(result.fetch("omitted_plugin_entities")).to include(
      "chat_channels" => 8,
      "chat_threads" => 1,
      "user_chat_thread_memberships" => 2,
    )
    expect(result.fetch("unsupported_entities").values).to all(be_zero)
  end

  it "keeps threads with titles unsupported" do
    stub_thread_title(true)

    expect(capture_plugin_inventory.fetch("unsupported_entities")).to include(
      "chat_threads" => 1,
      "user_chat_thread_memberships" => 2,
    )
  end

  it "keeps threads with custom fields unsupported" do
    counts["chat_thread_custom_fields"] = 1

    expect(capture_plugin_inventory.fetch("unsupported_entities")).to include(
      "chat_thread_custom_fields" => 1,
      "chat_threads" => 1,
      "user_chat_thread_memberships" => 2,
    )
  end

  it "keeps Chat with stored messages unsupported" do
    counts["chat_messages"] = 1

    result = capture_plugin_inventory

    expect(result.fetch("omitted_plugin_entities")).to be_empty
    expect(result.fetch("unsupported_entities")).to include(
      "chat_messages" => 1,
      "chat_threads" => 1,
      "user_chat_thread_memberships" => 2,
    )
  end
end
