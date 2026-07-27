# frozen_string_literal: true

require "tmpdir"

# A minimal stand-in for the import maps. Production wiring (mappings DB, uploads
# store, Discourse base URL) lands with the Posts import step; the resolver only
# depends on this small duck-typed surface.
class FakePlaceholderMaps
  def initialize(**lookups)
    @lookups = lookups
  end

  %i[
    user
    group_name
    post
    topic_id
    upload_markdown
    poll_markdown
    event_markdown
    category_slug_path
    category_id
    tag_name
    badge
    emoji_name
  ].each { |name| define_method(name) { |key| (@lookups[name] || {})[key] } }

  def base_url
    @lookups.fetch(:base_url, "https://dest.example.com")
  end

  def here_mention
    @lookups.fetch(:here_mention, "here")
  end
end

# Shared scaffolding for the PlaceholderResolver specs, split by phase under
# placeholder_resolver/. Sets up the migrated IntermediateDB and the default
# subject, so each phase file only carries its own examples.
RSpec.shared_context "with placeholder resolver" do
  subject(:resolver) { described_class.new(intermediate_db, maps, owner_type:) }

  let(:hashtag_type) { Migrations::Database::IntermediateDB::Enums::HashtagType }
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }
  let(:link_target) { Migrations::Database::IntermediateDB::Enums::LinkTarget }
  let(:embed_owner) { Migrations::Database::IntermediateDB::Enums::EmbedOwner }

  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }
  let(:intermediate_db) { @intermediate_db }
  let(:maps) { FakePlaceholderMaps.new }
  let(:owner_type) { embed_owner::POST }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@intermediate_db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end
end
