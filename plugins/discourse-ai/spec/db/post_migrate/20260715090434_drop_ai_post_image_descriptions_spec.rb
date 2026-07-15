# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/post_migrate/20260715090434_drop_ai_post_image_descriptions",
        )

describe DropAiPostImageDescriptions do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  after { connection.execute("DROP TABLE IF EXISTS ai_post_image_descriptions") }

  it "drops the legacy image descriptions table", :aggregate_failures do
    connection.execute("DROP TABLE IF EXISTS ai_post_image_descriptions")
    connection.execute("CREATE TABLE ai_post_image_descriptions (id bigserial PRIMARY KEY)")

    migration.up

    expect(connection.table_exists?(:ai_post_image_descriptions)).to eq(false)
    expect(connection.table_exists?(:ai_post_image_captions)).to eq(true)
  end
end
