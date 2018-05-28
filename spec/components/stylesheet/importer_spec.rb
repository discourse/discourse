require 'rails_helper'
require 'stylesheet/importer'

describe Stylesheet::Importer do

  def compile_css(name)
    Stylesheet::Compiler.compile_asset(name)[0]
  end

  def compile(stylesheet)
    Stylesheet::Compiler.compile(stylesheet, "test.scss", force: true)[0]
  end

  it "applies CDN to background category images" do
    expect(compile_css("category_backgrounds")).to_not include("background-image")

    background = Fabricate(:upload)
    category = Fabricate(:category, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(#{background.url})}")

    GlobalSetting.expects(:cdn_url).returns("//awesome.cdn")
    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(//awesome.cdn#{background.url})}")
  end

  it "applies S3 CDN to background category images" do
    SiteSetting.s3_use_iam_profile = true
    SiteSetting.s3_upload_bucket = 'test'
    SiteSetting.s3_region = 'ap-southeast-2'
    SiteSetting.s3_cdn_url = "https://s3.cdn"

    SiteSetting.enable_s3_uploads = true

    background = Fabricate(:upload_s3)
    category = Fabricate(:category, uploaded_background: background)

    expect(compile_css("category_backgrounds")).to include("body.category-#{category.full_slug}{background-image:url(https://s3.cdn/uploads")
  end

  it "imports from other themes" do
    theme = Theme.new(
      name: 'importer',
      user_id: -1
    )

    theme.set_field(target: :common, name: "scss", value: ".common{.scss{color: red;}}")
    theme.set_field(target: :desktop, name: "scss", value: ".desktop{.scss{color: red;}}")
    theme.set_field(target: :mobile, name: "scss", value: ".mobile{.scss{color: red;}}")
    theme.set_field(target: :common, name: "embedded_scss", value: ".embedded{.scss{color: red;}}")

    theme.save!

    expect(compile("@import \"themes/#{theme.id}/common\"; .child_common {color:red;}")).to include('.common')
    expect(compile("@import \"themes/#{theme.id}/desktop\"; .child_desktop {color:red;}")).to include('.desktop')
    expect(compile("@import \"themes/#{theme.id}/mobile\"; .child_mobile {color:red;}")).to include('.mobile')
    expect(compile("@import \"themes/#{theme.id}/common_embedded\"; .child_embedded {color:red;}")).to include('.embedded')
  end
end
