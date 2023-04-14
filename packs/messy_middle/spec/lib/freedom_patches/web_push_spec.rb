# frozen_string_literal: true

klass = defined?(WebPush) ? WebPush : Webpush

RSpec.describe klass do
  before do
    FinalDestination::SSRFDetector.allow_ip_lookups_in_test!
    WebMock.enable!(except: [:final_destination])
  end

  after do
    WebMock.enable!
    FinalDestination::SSRFDetector.disallow_ip_lookups_in_test!
  end

  it "should filter endpoint hostname through our SSRF detector" do
    klass::Request.any_instance.expects(:encrypt_payload)
    klass::Request.any_instance.expects(:headers)

    stub_ip_lookup("example.com", %W[0.0.0.0])

    expect do
      klass.payload_send(
        endpoint: "http://example.com",
        message: "test",
        p256dh: "somep256dh",
        auth: "someauth",
        vapid: {
          subject: "someurl",
          public_key: "somepublickey",
          private_key: "someprivatekey",
        },
      )
    end.to raise_error(FinalDestination::SSRFDetector::DisallowedIpError)
  end

  it "should send the right request if endpoint hostname resolves to a public ip address" do
    klass::Request.any_instance.expects(:encrypt_payload)
    klass::Request.any_instance.expects(:headers)

    stub_ip_lookup("example.com", %W[52.125.123.12])

    success = Class.new(StandardError)
    TCPSocket.stubs(:open).with { |addr| "52.125.123.12" == addr }.once.raises(success)

    expect do
      klass.payload_send(
        endpoint: "http://example.com",
        message: "test",
        p256dh: "somep256dh",
        auth: "someauth",
        vapid: {
          subject: "someurl",
          public_key: "somepublickey",
          private_key: "someprivatekey",
        },
      )
    end.to raise_error(success)
  end
end
