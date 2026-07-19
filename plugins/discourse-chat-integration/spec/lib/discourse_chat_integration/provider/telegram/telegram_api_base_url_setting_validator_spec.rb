# frozen_string_literal: true

RSpec.describe ChatIntegrationTelegramApiBaseUrlSettingValidator do
  subject(:validator) { described_class.new }

  it "accepts HTTPS base URLs" do
    valid_urls = %w[
      https://api.telegram.org
      https://telegram.example.com/
      https://telegram.example.com/api
    ]

    expect(valid_urls.map { |url| validator.valid_value?(url) }).to all(be(true))
  end

  it "rejects unsafe or malformed base URLs" do
    invalid_urls = [
      "http://telegram.example.com",
      "https:///telegram",
      "https://user:password@telegram.example.com",
      "https://telegram.example.com/?route=telegram",
      "https://telegram.example.com/#telegram",
      "not a URL",
    ]

    expect(invalid_urls.map { |url| validator.valid_value?(url) }).to all(be(false))
  end
end
