# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectoryItemSerializer do
  fab!(:user) { Fabricate(:user) }

  before do
    DirectoryItem.refresh!
  end

  let :serializer do
    directory_item = DirectoryItem.find_by(user: user, period_type: DirectoryItem.period_types[:all])
    DirectoryItemSerializer.new(directory_item, { attributes: DirectoryColumn.active_column_names })
  end

  it "Serializes attributes for enabled directory_columns" do
    DirectoryColumn.update_all(enabled: true)

    payload = serializer.as_json
    expect(payload[:directory_item].keys).to include(*DirectoryColumn.pluck(:name).map(&:to_sym))
  end

  it "Doesn't serialize attributes for disabled directory columns" do
    DirectoryColumn.update_all(enabled: false)
    directory_column = DirectoryColumn.first
    directory_column.update(enabled: true)

    payload = serializer.as_json
    expect(payload[:directory_item].keys.count).to eq(4)
    expect(payload[:directory_item]).to have_key(directory_column.name.to_sym)
    expect(payload[:directory_item]).to have_key(:id)
    expect(payload[:directory_item]).to have_key(:user)
    expect(payload[:directory_item]).to have_key(:time_read)
  end
end
