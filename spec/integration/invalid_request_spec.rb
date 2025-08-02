# frozen_string_literal: true

RSpec.describe "invalid requests", type: :request do
  let(:fake_logger) { FakeLogger.new }

  before { Rails.logger.broadcast_to(fake_logger) }

  after { Rails.logger.stop_broadcasting_to(fake_logger) }

  it "handles NotFound with invalid json body" do
    post "/latest.json",
         params: "{some: malformed: json",
         headers: {
           "content-type" => "application/json",
         }
    expect(response.status).to eq(404)
    expect(fake_logger.warnings).to be_empty
    expect(fake_logger.errors).to have_attributes(size: 1)
  end

  it "handles EOFError when multipart request is malformed" do
    post "/latest.json",
         params: "somecontent",
         headers: {
           "content-type" => "multipart/form-data; boundary=abcde",
           "content-length" => "1",
         }
    expect(response.status).to eq(400)
    expect(fake_logger.warnings).to be_empty
    expect(fake_logger.errors).to have_attributes(size: 1)
  end

  it "handles invalid parameters" do
    post "/latest.json", params: { "foo" => "\255bar" }
    expect(response.status).to eq(404)
    expect(fake_logger.warnings).to be_empty
    expect(fake_logger.errors).to have_attributes(size: 1)
  end
end
