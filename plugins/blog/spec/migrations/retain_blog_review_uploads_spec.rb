# frozen_string_literal: true

require Rails.root.join("plugins/blog/db/migrate/20261008205400_retain_blog_review_uploads.rb")

RSpec.describe RetainBlogReviewUploads do
  fab!(:admin)
  fab!(:topic)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    allow(Migration::Helpers).to receive(:existing_site?).and_return(true)
    # This migration predates the table rename.
    DB.exec("CREATE VIEW discourse_blog_reviews AS SELECT * FROM blog_reviews")
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def create_snapshot(cooked, **attributes)
    review =
      Blog::Review.create!(
        topic: topic,
        creator: admin,
        title: topic.title,
        cooked: cooked,
        post_version: 1,
        token: SecureRandom.urlsafe_base64(32),
        expires_at: 7.days.from_now,
        **attributes,
      )
    UploadReference.where(target: review).delete_all
    review
  end

  # This migration predates the rename, so it writes the old class name.
  def references(*reviews)
    UploadReference.where(target_type: "DiscourseBlog::Review", target_id: reviews.map(&:id))
  end

  it "backfills original and optimized uploads only for active snapshots, idempotently" do
    upload = Fabricate(:upload, user: admin)
    optimized_upload = Fabricate(:upload, user: admin)
    optimized = Fabricate(:optimized_image, upload: optimized_upload)
    cooked = "<p><img src=\"#{upload.url}\"><img src=\"#{optimized.url}\"></p>"
    active = create_snapshot(cooked)
    expired = create_snapshot(cooked, expires_at: 1.day.ago)
    revoked = create_snapshot(cooked, revoked_at: Time.current)

    2.times { described_class.new.up }

    expect(references(active).pluck(:upload_id)).to contain_exactly(upload.id, optimized_upload.id)
    expect(references(expired, revoked)).not_to exist
  end

  it "retains attachments whose cooked links use short upload paths" do
    upload = Fabricate(:upload, user: admin)
    path = "/uploads/short-url/#{Upload.base62_sha1(upload.sha1)}.#{upload.extension}"
    cooked = PrettyText.cook("[Attachment](#{path})")
    expect(cooked).to include(path)
    review = create_snapshot(cooked)

    described_class.new.up

    expect(references(review).pluck(:upload_id)).to eq([upload.id])
  end

  it "writes no references on fresh installs" do
    upload = Fabricate(:upload, user: admin)
    review = create_snapshot("<p><img src=\"#{upload.url}\"></p>")
    allow(Migration::Helpers).to receive(:existing_site?).and_return(false)

    described_class.new.up

    expect(references(review)).not_to exist
  end
end
