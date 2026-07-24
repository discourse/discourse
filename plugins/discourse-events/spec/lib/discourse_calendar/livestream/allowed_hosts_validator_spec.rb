# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::AllowedHostsValidator do
  subject(:validator) { described_class.new }

  it "accepts bare hosts" do
    expect(validator.valid_value?("youtube.com|us06web.zoom.us|youtu.be")).to eq(true)
  end

  it "accepts an empty list" do
    expect(validator.valid_value?("")).to eq(true)
    expect(validator.valid_value?(nil)).to eq(true)
  end

  it "rejects an entry carrying a scheme, path or port" do
    expect(validator.valid_value?("https://vimeo.com")).to eq(false)
    expect(validator.valid_value?("vimeo.com/videos")).to eq(false)
    expect(validator.valid_value?("vimeo.com:443")).to eq(false)
  end

  it "rejects a non-ASCII host, which is listed in punycode instead" do
    expect(validator.valid_value?("ｙoutube.com")).to eq(false)
    expect(validator.valid_value?("xn--80ak6aa92e.com")).to eq(true)
  end

  it "rejects wildcards, which the default host_list validator would have caught" do
    expect(validator.valid_value?("*.zoom.us")).to eq(false)
    expect(validator.valid_value?("zoom.?s")).to eq(false)
  end

  it "names every offending entry, leaving the valid ones out of the message" do
    expect(validator.valid_value?("youtube.com|https://vimeo.com|zoom.us/j")).to eq(false)

    expect(validator.error_message).to include("https://vimeo.com", "zoom.us/j")
    expect(validator.error_message).not_to include("youtube.com")
  end

  it "is wired up to the site setting" do
    expect { SiteSetting.livestream_allowed_hosts = "https://vimeo.com/videos" }.to raise_error(
      Discourse::InvalidParameters,
    )

    expect { SiteSetting.livestream_allowed_hosts = "vimeo.com" }.not_to raise_error
  end
end
