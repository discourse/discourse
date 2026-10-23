# frozen_string_literal: true

RSpec.describe "Forwarded headers initializer" do
  let(:env) do
    Rack::MockRequest.env_for(
      "http://test.localhost/",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "198.51.100.7",
      "HTTP_X_FORWARDED_PROTO" => "http",
      "HTTP_FORWARDED" => "for=203.0.113.9;proto=https;host=evil.example",
    )
  end

  it "ignores the Forwarded header in Rack requests" do
    request = Rack::Request.new(env)

    expect(request.ip).to eq("198.51.100.7")
    expect(request.ssl?).to eq(false)
    expect(request.host).to eq("test.localhost")
  end

  it "ignores the Forwarded header in the Rails remote IP" do
    remote_ip = nil
    app =
      lambda do |request_env|
        remote_ip = ActionDispatch::Request.new(request_env).remote_ip
        [200, {}, []]
      end

    ActionDispatch::RemoteIp.new(app).call(env)

    expect(remote_ip).to eq("198.51.100.7")
  end
end
