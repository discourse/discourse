require 'rails_helper'
require 'stylesheet/importer'

describe Stylesheet::Importer do

  def compile_css(name)
    Stylesheet::Compiler.compile_asset(name)[0]
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

end
