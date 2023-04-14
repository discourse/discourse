# frozen_string_literal: true

describe "Secure uploads" do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:secure_category) { Fabricate(:private_category, group: group) }

  before do
    Jobs.run_immediately!

    # this is done so the after_save callbacks for site settings to make
    # UploadReference records works
    @original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
    setup_s3
    stub_s3_store
    SiteSetting.secure_uploads = true
    group.add(user)
    user.reload
  end

  after { SiteSetting.provider = @original_provider }

  def create_upload
    filename = "logo.png"
    file = file_from_fixtures(filename)
    UploadCreator.new(file, filename).create_for(user.id)
  end

  def stub_presign_upload_get(upload)
    # this is necessary because by default any upload inside a secure post is considered "secure"
    # for the purposes of fetching hotlinked images until proven otherwise, and this is easier
    # than trying to stub the presigned URL for s3 in a different way
    stub_request(:get, "https:#{upload.url}").to_return(
      status: 200,
      body: file_from_fixtures("logo.png"),
    )
    Upload.stubs(:signed_url_from_secure_uploads_url).returns("https:#{upload.url}")
  end

  it "does not convert an upload to secure when it was first used in a site setting then in a post" do
    upload = create_upload
    SiteSetting.favicon = upload
    expect(upload.reload.upload_references.count).to eq(1)
    create_post(
      title: "Secure upload post",
      raw: "This is a new post <img src=\"#{upload.url}\" />",
      category: secure_category,
      user: user,
    )
    upload.reload
    expect(upload.upload_references.count).to eq(2)
    expect(upload.secure).to eq(false)
  end

  it "does not convert an upload to insecure when it was first used in a secure post then a site setting" do
    upload = create_upload
    create_post(
      title: "Secure upload post",
      raw: "This is a new post <img src=\"#{upload.url}\" />",
      category: secure_category,
      user: user,
    )
    expect(upload.reload.upload_references.count).to eq(1)
    SiteSetting.favicon = upload
    upload.reload
    expect(upload.upload_references.count).to eq(2)
    expect(upload.secure).to eq(true)
  end

  it "does not convert an upload to secure when it was first used in a public post then in a secure post" do
    upload = create_upload

    post =
      create_post(
        title: "Public upload post",
        raw: "This is a new post <img src=\"#{upload.url}\" />",
        user: user,
      )
    upload.reload
    expect(upload.upload_references.count).to eq(1)
    expect(upload.secure).to eq(false)
    expect(upload.access_control_post).to eq(post)

    stub_presign_upload_get(upload)
    create_post(
      title: "Secure upload post",
      raw: "This is a new post <img src=\"#{upload.url}\" />",
      category: secure_category,
      user: user,
    )
    upload.reload
    expect(upload.upload_references.count).to eq(2)
    expect(upload.secure).to eq(false)
    expect(upload.access_control_post).to eq(post)
  end

  it "does not convert an upload to insecure when it was first used in a secure post then in a public post" do
    upload = create_upload

    stub_presign_upload_get(upload)
    post =
      create_post(
        title: "Secure upload post",
        raw: "This is a new post <img src=\"#{upload.url}\" />",
        category: secure_category,
        user: user,
      )
    upload.reload
    expect(upload.upload_references.count).to eq(1)
    expect(upload.secure).to eq(true)
    expect(upload.access_control_post).to eq(post)

    create_post(
      title: "Public upload post",
      raw: "This is a new post <img src=\"#{upload.url}\" />",
      user: user,
    )
    upload.reload
    expect(upload.upload_references.count).to eq(2)
    expect(upload.secure).to eq(true)
    expect(upload.access_control_post).to eq(post)
  end
end
