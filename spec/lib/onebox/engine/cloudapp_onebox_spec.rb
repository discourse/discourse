# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::CloudAppOnebox do
  before do
    fake("https://cl.ly/0m2a2u2k440O", response("cloudapp-gif"))
    fake("https://cl.ly/0T0c2J3S373X", response("cloudapp-mp4"))
    fake("https://cl.ly/2C0E1V451J0C", response("cloudapp-jpg"))
    fake("https://cl.ly/1x1f2g253l03", response("cloudapp-others"))
  end

  it "supports gif" do
    expect(Onebox.preview('https://cl.ly/0m2a2u2k440O').to_s).to match(/<img/)
  end

  it "supports mp4" do
    expect(Onebox.preview('https://cl.ly/0T0c2J3S373X').to_s).to match(/<video/)
  end

  it "supports jpg" do
    expect(Onebox.preview('https://cl.ly/2C0E1V451J0C').to_s).to match(/<img/)
  end

  it "links to other formats" do
    expect(Onebox.preview('https://cl.ly/1x1f2g253l03').to_s).to match(/<a/)
  end
end
