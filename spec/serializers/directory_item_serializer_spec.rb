# frozen_string_literal: true

RSpec.describe DirectoryItemSerializer do
  fab!(:user)
  fab!(:directory_column) do
    DirectoryColumn.create!(name: "topics_entered", enabled: true, position: 1)
  end
  fab!(:user_field_1) { Fabricate(:user_field, name: "user_field_1", searchable: true) }
  fab!(:user_field_2) { Fabricate(:user_field, name: "user_field_2", searchable: false) }

  before { DirectoryItem.refresh! }

  context "when serializing user fields" do
    it "serializes user fields with searchable and non-searchable values" do
      user.user_custom_fields.create!(name: "user_field_1", value: "Value 1")
      user.user_custom_fields.create!(name: "user_field_2", value: "Value 2")

      user_fields =
        serialized_payload(
          attributes: DirectoryColumn.active_column_names,
          user_custom_field_map: {
            "user_field_1" => user_field_1.id,
            "user_field_2" => user_field_2.id,
          },
          searchable_fields: [user_field_1],
        )

      expect(user_fields).to eq(
        user_field_1.id => {
          value: ["Value 1"],
          searchable: true,
        },
        user_field_2.id => {
          value: ["Value 2"],
          searchable: false,
        },
      )
    end

    it "handles multiple values for the same field" do
      user.user_custom_fields.create!(name: "user_field_1", value: "Value 1")
      user.user_custom_fields.create!(name: "user_field_1", value: "Another Value")

      user_fields =
        serialized_payload(
          attributes: DirectoryColumn.active_column_names,
          user_custom_field_map: {
            "user_field_1" => user_field_1.id,
          },
          searchable_fields: [],
        )

      expect(user_fields[user_field_1.id]).to eq(
        value: ["Value 1", "Another Value"],
        searchable: false,
      )
    end
  end

  context "when serializing directory columns" do
    let :serializer do
      directory_item =
        DirectoryItem.find_by(user: user, period_type: DirectoryItem.period_types[:all])
      DirectoryItemSerializer.new(
        directory_item,
        { attributes: DirectoryColumn.active_column_names },
      )
    end

    it "serializes attributes for enabled directory_columns" do
      DirectoryColumn.update_all(enabled: true)

      payload = serializer.as_json
      expect(payload[:directory_item].keys).to include(*DirectoryColumn.pluck(:name).map(&:to_sym))
    end

    it "doesn't serialize attributes for disabled directory columns" do
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

  private

  def serialized_payload(serializer_opts)
    serializer = DirectoryItemSerializer.new(DirectoryItem.find_by(user: user), serializer_opts)
    serializer.as_json.dig(:directory_item, :user, :user_fields)
  end
end
