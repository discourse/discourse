# frozen_string_literal: true

RSpec.describe "SecureLinkFlow" do
  let(:server_session) { ServerSession.new("secure-link-flow-#{SecureRandom.hex}") }
  let(:flow) { SecureLinkFlow.new(server_session) }

  it "stores a credential for ten minutes" do
    flow.stage(:password_reset, "secret")

    expect(flow.credential(:password_reset)).to eq("secret")
    expect(server_session.ttl("secure-link-password-reset")).to be_between(599, 600)
  end

  it "replaces an older credential for the same purpose" do
    flow.stage(:password_reset, "first")
    flow.stage(:password_reset, "second")

    expect(flow.credential(:password_reset)).to eq("second")
  end

  it "keeps credentials isolated by purpose" do
    flow.stage(:password_reset, "password-secret")
    flow.stage(:email_login, "login-secret")

    expect(flow.credential(:password_reset)).to eq("password-secret")
    expect(flow.credential(:email_login)).to eq("login-secret")
  end

  it "clears a credential" do
    flow.stage(:password_reset, "secret")

    flow.clear(:password_reset)

    expect(flow.credential(:password_reset)).to be_nil
  end

  it "claims and clears a credential" do
    flow.stage(:password_reset, "secret")

    expect(flow.claim(:password_reset)).to eq("secret")
    expect(flow.credential(:password_reset)).to be_nil
  end

  it "rejects an unknown purpose" do
    expect { flow.stage(:unknown, "secret") }.to raise_error(ArgumentError)
  end
end
