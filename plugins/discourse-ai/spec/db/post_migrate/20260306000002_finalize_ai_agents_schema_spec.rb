# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/post_migrate/20260306000002_finalize_ai_agents_schema",
        )

describe FinalizeAiAgentsSchema do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  let(:settings) do
    %w[ai_helper_image_caption_persona ai_helper_image_caption_agent ai_image_caption_agent]
  end

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { delete_settings }

  after { delete_settings }

  def delete_settings
    quoted_names = settings.map { |name| connection.quote(name) }.join(", ")
    connection.execute("DELETE FROM site_settings WHERE name IN (#{quoted_names})")
  end

  def store_setting(name, value)
    connection.execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES (#{connection.quote(name)}, #{SiteSetting.types[:enum]}, #{connection.quote(value)}, NOW(), NOW())
    SQL
  end

  def setting_value(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = :name", name: name).first
  end

  it "renames the legacy image caption persona setting to the current image caption agent setting",
     :aggregate_failures do
    store_setting("ai_helper_image_caption_persona", "-26")

    migration.up

    expect(setting_value("ai_image_caption_agent")).to eq("-26")
    expect(setting_value("ai_helper_image_caption_agent")).to be_nil
    expect(setting_value("ai_helper_image_caption_persona")).to be_nil
  end
end
