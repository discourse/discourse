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

  # Creates an embed row of `kind` for owner 1 and returns its placeholder
  # token, so an example is only its row attributes and expectation.
  def create_embed(kind, **attributes)
    token = placeholder.mint(kind)
    Migrations::Database::IntermediateDB.const_get("Embed#{kind.capitalize}").create(
      owner_type:,
      owner_id: 1,
      placeholder: token,
      **attributes,
    )
    token
  end

  # The source records a resolver example looks a recorded name up against.

  def create_user(original_id, username)
    Migrations::Database::IntermediateDB::User.create(
      original_id:,
      username:,
      created_at: Time.now,
      trust_level: 0,
    )
  end

  def create_category(original_id, slug, parent_category_id: nil)
    Migrations::Database::IntermediateDB::Category.create(
      original_id:,
      name: slug,
      slug:,
      parent_category_id:,
      user_id: 1,
    )
  end

  def create_tag(original_id, name)
    Migrations::Database::IntermediateDB::Tag.create(original_id:, name:, slug: name)
  end

  def create_topic(original_id, slug)
    Migrations::Database::IntermediateDB::Topic.create(original_id:, title: slug, slug:)
  end

  # Resolves one owner-1 body; `maps:` builds a fresh resolver over those
  # lookups, without it the shared subject resolves (so an example can inspect
  # `resolver.unresolved_embeds` afterwards).
  def resolve(raw, maps: nil)
    instance = maps ? described_class.new(intermediate_db, maps, owner_type:) : resolver
    instance.resolve_all([{ id: 1, raw: }])[1]
  end

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
