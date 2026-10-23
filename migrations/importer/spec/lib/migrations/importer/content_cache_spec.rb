# frozen_string_literal: true

RSpec.describe Migrations::Importer::ContentCache, :rails do
  let!(:post) { Fabricate(:post, raw: "A paragraph with **bold** text.") }

  around do |example|
    Dir.mktmpdir do |directory|
      @cache_path = File.join(directory, "cache.db")
      example.run
    end
  end

  before do
    SiteSetting.content_localization_enabled = true
    post.update_columns(
      locale: "en",
      cooked: "<p>A paragraph with <strong>bold</strong> text.</p>",
      baked_version: Post::BAKED_VERSION,
    )
    post.sync_first_post_caches
    PostCustomField.create!(post:, name: "import_id", value: "post-1")
    TopicCustomField.create!(topic: post.topic, name: "import_id", value: "topic-1")
    PostLocalization.create!(
      post:,
      locale: "fr",
      raw: "Un paragraphe.",
      cooked: "<p>Un paragraphe.</p>",
      post_version: post.version,
      localizer_user_id: Discourse::SYSTEM_USER_ID,
    )
    TopicLocalization.create!(
      topic: post.topic,
      locale: "fr",
      title: "Un titre",
      fancy_title: "Un titre",
      excerpt: "Un paragraphe.",
      localizer_user_id: Discourse::SYSTEM_USER_ID,
    )
  end

  def export_cache
    described_class.new.export(@cache_path)
  end

  def clear_translations
    post.localizations.destroy_all
    post.topic.localizations.destroy_all
  end

  it "restores onto different IDs and versions and rebuilds first-post excerpts" do
    export_cache
    destination = Fabricate(:post, raw: post.raw, version: 4)
    destination.topic.update_column(:title, post.topic.title)
    destination.update_columns(baked_version: nil, cooked: "temporary")
    PostCustomField.where(post_id: post.id, name: "import_id").update_all(post_id: destination.id)
    TopicCustomField.where(topic_id: post.topic_id, name: "import_id").update_all(
      topic_id: destination.topic_id,
    )

    counts = described_class.new.restore(@cache_path)

    expect(destination.reload.cooked).to eq(post.cooked)
    expect(destination.baked_version).to eq(Post::BAKED_VERSION)
    expect(destination.locale).to eq("en")
    localization = destination.localizations.find_by!(locale: "fr")
    expect(localization.post_version).to eq(4)
    expect(localization.raw).to eq("Un paragraphe.")
    expect(destination.topic.localizations.find_by!(locale: "fr").title).to eq("Un titre")
    expect(counts[:cooked_hits]).to eq(1)
  end

  it "misses changed raw and changed identity without restoring translations" do
    export_cache
    clear_translations
    post.update_columns(raw: "Changed raw", cooked: "changed", baked_version: nil)
    counts = described_class.new.restore(@cache_path)
    expect(post.reload.cooked).to eq("changed")
    expect(post.localizations).to be_empty
    expect(counts[:post_misses]).to eq(1)

    post.update_column(:raw, "A paragraph with **bold** text.")
    PostCustomField.where(post_id: post.id, name: "import_id").update_all(value: "other-post")
    described_class.new.restore(@cache_path)
    expect(post.localizations).to be_empty
  end

  it "preserves destination translations when restoration is repeated" do
    export_cache
    clear_translations
    described_class.new.restore(@cache_path)
    post
      .localizations
      .find_by!(locale: "fr")
      .update!(raw: "Manually edited", cooked: "<p>Manually edited</p>")
    described_class.new.restore(@cache_path)
    expect(post.localizations.count).to eq(1)
    expect(post.localizations.reload.first.raw).to eq("Manually edited")
    expect(post.topic.localizations.count).to eq(1)
  end

  it "excludes stale post translations and ambiguous original IDs" do
    post.localizations.update_all(post_version: post.version + 1)
    counts = export_cache
    clear_translations
    described_class.new.restore(@cache_path)
    expect(post.localizations).to be_empty
    expect(counts[:stale_translations]).to eq(1)

    PostCustomField.create!(post: Fabricate(:post), name: "import_id", value: "post-1")
    counts = export_cache
    expect(counts[:exported_posts]).to eq(0)
  end

  it "rejects changed topic titles independently of post translations" do
    export_cache
    clear_translations
    post.topic.update!(title: "A different title")
    described_class.new.restore(@cache_path)
    expect(post.localizations.count).to eq(1)
    expect(post.topic.localizations).to be_empty
  end

  it "invalidates translations when an import changes their source without incrementing versions" do
    cache = described_class.new
    cache.capture_existing_sources
    post.update_column(:raw, "A changed source")
    cache.invalidate_changed_sources
    expect(post.localizations).to be_empty
    expect(post.topic.localizations).to be_empty
    expect(post.reload.locale).to be_nil
  end

  it "recooks translations when rendering settings change" do
    export_cache
    clear_translations
    SiteSetting.enable_emoji = !SiteSetting.enable_emoji
    counts = described_class.new.restore(@cache_path)
    expect(counts[:cooked_hits]).to eq(0)
    expect(post.localizations.reload.first.cooked).to include("Un paragraphe.")
  end

  it "rewrites cached HTML and translated raw when the destination hostname changes" do
    source_url = Discourse.base_url
    raw = "[link](#{source_url}/t/123)"
    cooked = "<p><a href=\"#{source_url}/t/123\">link</a></p>"
    post.update_columns(raw:, cooked:)
    post.localizations.first.update!(raw:, cooked:)
    export_cache
    clear_translations
    Discourse.stubs(:base_url).returns("https://destination.example")

    counts = described_class.new.restore(@cache_path)

    expect(post.reload.cooked).to include('href="https://destination.example/t/123"')
    translation = post.localizations.reload.first
    expect(translation.raw).to eq("[link](https://destination.example/t/123)")
    expect(translation.cooked).to include('href="https://destination.example/t/123"')
    expect(counts[:rewritten_fields]).to be >= 2
  end

  it "checks upload dependencies even for plain attachment links" do
    upload = Fabricate(:upload)
    post.update_columns(
      raw: "[attachment](#{upload.short_url})",
      cooked: "<p><a href=\"#{upload.url}\">attachment</a></p>",
    )
    post.link_post_uploads
    expect(post.uploads).to contain_exactly(upload)
    export_cache
    upload.update_column(:url, "/uploads/changed/attachment.png")

    counts = described_class.new.restore(@cache_path)

    expect(counts[:cooked_hits]).to eq(0)
    expect(counts[:cooked_misses]).to eq(1)
  end

  it "recooks dynamic markup without reusing source-specific mention IDs" do
    source_cooked = '<p><a class="mention" data-user-id="123456">@someone</a></p>'
    post.update_columns(cooked: source_cooked)
    post.localizations.first.update!(cooked: source_cooked)
    export_cache
    clear_translations
    post.update_columns(cooked: "temporary", baked_version: nil)

    counts = described_class.new.restore(@cache_path)

    expect(counts[:cooked_hits]).to eq(0)
    expect(post.reload.cooked).not_to include("123456")
    expect(post.localizations.reload.first.cooked).to include("Un paragraphe.")
  end

  it "maps human localizers by original ID and preserves multiple locales" do
    source_user = Fabricate(:user)
    destination_user = Fabricate(:user)
    mapping = UserCustomField.create!(user: source_user, name: "import_id", value: "translator-1")
    post.localizations.first.update!(localizer_user_id: source_user.id)
    PostLocalization.create!(
      post:,
      locale: "de",
      raw: "Ein Absatz.",
      cooked: "<p>Ein Absatz.</p>",
      post_version: post.version,
      localizer_user_id: Discourse::SYSTEM_USER_ID,
    )
    export_cache
    clear_translations
    mapping.update!(user: destination_user)

    described_class.new.restore(@cache_path)

    expect(post.localizations.reload.pluck(:locale, :localizer_user_id)).to contain_exactly(
      ["fr", destination_user.id],
      ["de", Discourse::SYSTEM_USER_ID],
    )
  end
end
