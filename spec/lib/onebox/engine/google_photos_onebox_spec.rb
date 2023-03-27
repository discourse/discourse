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
end
