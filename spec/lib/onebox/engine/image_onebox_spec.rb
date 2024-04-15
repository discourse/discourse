# frozen_string_literal: true

RSpec.describe Onebox::Engine::ImageOnebox do
  it "supports png" do
    expect(Onebox.preview("http://www.discourse.org/images/logo.png").to_s).to match(/<img/)
  end

  it "supports jpg" do
    expect(
      Onebox.preview("http://upload.wikimedia.org/wikipedia/en/a/a9/Example.jpg").to_s,
    ).to match(/<img/)
  end

  it "supports jpeg" do
    expect(
      Onebox.preview("http://upload.wikimedia.org/wikipedia/en/b/bb/Poster.jpeg").to_s,
    ).to match(/<img/)
  end

  it "supports gif" do
    expect(
      Onebox.preview("http://upload.wikimedia.org/wikipedia/commons/5/55/Tesseract.gif").to_s,
    ).to match(/<img/)
  end

  it "supports tif" do
    expect(
      Onebox.preview(
        "http://www.fileformat.info/format/tiff/sample/1f37bbd5603048178487ec88b1a6425b/MARBLES.tif",
      ).to_s,
    ).to match(/<img/)
  end

  it "supports bmp" do
    expect(
      Onebox.preview(
        "http://www.fileformat.info/format/bmp/sample/d4202a5fc22a48c388d9e1c636792cc6/LAND.BMP",
      ).to_s,
    ).to match(/<img/)
  end

  it "supports webp" do
    expect(Onebox.preview("https://www.gstatic.com/webp/gallery/1.sm.webp").to_s).to match(/<img/)
  end

  it "supports avif" do
    expect(
      Onebox.preview(
        "https://raw.githubusercontent.com/AOMediaCodec/av1-avif/master/testFiles/Xiph/abandoned_filmgrain.avif",
      ).to_s,
    ).to match(/<img/)
  end

  it "supports image URLs with query parameters" do
    expect(
      Onebox.preview(
        "https://www.google.com/logos/doodles/2014/percy-julians-115th-birthday-born-1899-5688801926053888-hp.jpg?foo=bar",
      ).to_s,
    ).to match(/<img/)
  end

  it "supports protocol relative image URLs" do
    expect(
      Onebox.preview(
        "//www.google.com/logos/doodles/2014/percy-julians-115th-birthday-born-1899-5688801926053888-hp.jpg",
      ).to_s,
    ).to match(/<img/)
  end

  it "includes a direct link to the image" do
    expect(Onebox.preview("http://www.discourse.org/images/logo.png").to_s).to match(/<a.*png/)
  end

  it "matches on content_type" do
    expect(
      Onebox.preview("http://www.discourse.org/images/logo", { content_type: "image/png" }).to_s,
    ).to match(/<img/)
  end
end
