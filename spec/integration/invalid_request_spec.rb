# frozen_string_literal: true

require 'rails_helper'

describe 'invalid requests', type: :request do
  before do
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
  end

  after do
    Rails.logger = @orig_logger
  end

  it "handles NotFound with invalid json body" do
    post "/latest.json", params: "{some: malformed: json", headers: { "content-type" => "application/json" }
    expect(response.status).to eq(404)
    expect(@fake_logger.warnings.length).to eq(0)
    expect(@fake_logger.errors.length).to eq(0)
  end

  it "handles EOFError when multipart request is malformed" do
    post "/latest.json", params: "somecontent", headers: {
      "content-type" => "multipart/form-data; boundary=abcde",
      "content-length" => "1"
    }
    expect(response.status).to eq(400)
    expect(@fake_logger.warnings.length).to eq(0)
    expect(@fake_logger.errors.length).to eq(0)
  end

  it "handles invalid parameters" do
    post "/latest.json", params: { "foo" => "\255bar" }
    expect(response.status).to eq(404)
    expect(@fake_logger.warnings.length).to eq(0)
    expect(@fake_logger.errors.length).to eq(0)
  end

end
