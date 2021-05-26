# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::GoogleDriveOnebox do
  let(:link) { "https://drive.google.com/file/d/1FgMt06wENEUfC6_-1tImXaNCH7vM9QsA/view" }
  let(:html) { described_class.new(link).to_html }

  before do
    stub_request(:get, link).to_return(status: 200, body: onebox_response("googledrive"))
  end

  it "includes title" do
    expect(html).to include('<a href="https://drive.google.com/file/d/1FgMt06wENEUfC6_-1tImXaNCH7vM9QsA/view" target="_blank" rel="noopener">test.txt</a>')
  end

  it "includes image" do
    expect(html).to include("https://lh5.googleusercontent.com/wcDbcSFKB3agLf0963iFPqwy96OE2s7of1pAEbEOpg-38yS_m7u8VHKezWQ=w1200-h630-p")
  end

  it "includes description" do
    expect(html).to include("Awesome description here! 😎")
  end
end
