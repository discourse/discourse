require "spec_helper"

describe Onebox::Engine::ImageOnebox do
  it "supports png" do
    Onebox.preview('http://www.discourse.org/images/logo.png').to_s.should match(/<img/)
  end

  it "supports jpeg" do
    Onebox.preview('http://upload.wikimedia.org/wikipedia/en/b/bb/Poster.jpeg').to_s.should match(/<img/)
  end

  it "supports gif" do
    Onebox.preview('http://upload.wikimedia.org/wikipedia/commons/5/55/Tesseract.gif').to_s.should match(/<img/)
  end

  it "supports image URLs with query parameters" do
    Onebox.preview('https://www.google.com/logos/doodles/2014/percy-julians-115th-birthday-born-1899-5688801926053888-hp.jpg?foo=bar').to_s.should match(/<img/)
  end

  it "includes a direct link to the image" do
    Onebox.preview('http://www.discourse.org/images/logo.png').to_s.should match(/<a.*png/)
  end
end
