# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260708051450_remove_image_caption_from_ai_helper_enabled_features",
        )

describe RemoveImageCaptionFromAiHelperEnabledFeatures do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { delete_setting }

  after { delete_setting }

  def delete_setting
    connection.execute("DELETE FROM site_settings WHERE name = 'ai_helper_enabled_features'")
  end

  def store_enabled_features(value)
    connection.execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('ai_helper_enabled_features', 20, '#{value}', NOW(), NOW())
    SQL
  end

  def enabled_features
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'ai_helper_enabled_features'",
    ).first
  end

  it "removes the image caption feature from stored helper features", :aggregate_failures do
    store_enabled_features("suggestions|image_caption|context_menu")

    migration.up

    expect(enabled_features).to eq("suggestions|context_menu")

    delete_setting
    store_enabled_features("image_caption")

    migration.up

    expect(enabled_features).to eq("")
  end
end
