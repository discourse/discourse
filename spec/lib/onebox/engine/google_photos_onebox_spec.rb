# frozen_string_literal: true

RSpec.describe Onebox::Engine::GooglePhotosOnebox do
  let(:link) { "https://photos.app.goo.gl/pXA7T8zBX4WZWVMT7" }
  let(:html) { described_class.new(link).to_html }

  before do
    stub_request(:get, link).to_return(status: 200, body: onebox_response("googlephotos"))
    stub_request(
      :get,
      "https://photos.google.com/share/AF1QipOV3gcu_edA8lyjJEpS9sC1g3AeCUtaZox11ylYZId7wJ7cthZ8M1kZXeAp5vhEPg?key=QktmUFNvdWpNVktERU5zWmVRZlZubzRRc0ttWWN3",
    ).to_return(status: 200, body: onebox_response("googlephotos"))
    stub_request(
      :head,
      "https://photos.google.com/share/AF1QipOV3gcu_edA8lyjJEpS9sC1g3AeCUtaZox11ylYZId7wJ7cthZ8M1kZXeAp5vhEPg?key=QktmUFNvdWpNVktERU5zWmVRZlZubzRRc0ttWWN3",
    ).to_return(status: 200, body: "")
  end

  it "includes album title" do
    expect(html).to include("[3 new photos · Album by Arpit Jalan] Mesmerizing Singapore")
  end

  it "includes album poster image" do
    expect(html).to include(
      "https://lh3.googleusercontent.com/ZlYoleNnrVo8qdx0qEjKi_-_VXY7pqqCqIW-B88EMqJ0etibFw1kEu4bzo-T4jyOQ9Ey2ekADim_L3re4lT3aBmYJUwhjkEUb5Yk59YaCSy2R8AoME5Rx4wviDRgICllF8g6lsZnS8c=w600-h315-p-k",
    )
  end

  describe ".===" do
    it "matches valid Google Photos URL with google.com domain" do
      valid_url = URI("https://photos.google.com/share/abcd1234")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Google Photos URL with app.goo.gl domain" do
      valid_url_short = URI("https://photos.app.goo.gl/abcd1234")
      expect(described_class === valid_url_short).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://photos.google.com.malicious.com/share/abcd1234")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.photos.google.com/share/abcd1234")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match URL with unsupported domain" do
      invalid_url = URI("https://photos.otherdomain.com/share/abcd1234")
      expect(described_class === invalid_url).to eq(false)
    end
  end
end
