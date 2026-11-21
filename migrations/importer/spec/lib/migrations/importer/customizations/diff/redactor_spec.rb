# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Diff::Redactor do
  subject(:redactor) { described_class.new(secret_setting_names: Set["some_client_id"]) }

  it "redacts credential columns" do
    redact = redactor.for("users", %w[id username password_hash])
    row = redact.call(%w[1 alice hash-value])

    expect(row[0, 2]).to eq(%w[1 alice])
    expect(row[2]).to match(/\A\[redacted:\h{8}\]\z/)
  end

  it "redacts values by setting name, from the pattern and from the flags" do
    redact = redactor.for("site_settings", %w[id name value])

    expect(redact.call(%w[1 github_client_secret abc])[2]).to start_with("[redacted:")
    expect(redact.call(%w[2 some_client_id abc])[2]).to start_with("[redacted:")
    expect(redact.call(%w[3 title abc])[2]).to eq("abc")
  end

  it "uses `key` as the name column, e.g. for plugin store rows" do
    redact = redactor.for("plugin_store_rows", %w[id plugin_name key value])
    expect(redact.call(%w[1 x my_api_key abc])[3]).to start_with("[redacted:")
  end

  it "uses the broad pattern for key/value tables without secret flags" do
    store = redactor.for("plugin_store_rows", %w[id plugin_name key value])
    fields = redactor.for("user_custom_fields", %w[id user_id name value])
    settings = redactor.for("site_settings", %w[id name value])

    expect(store.call(%w[1 x oauth_token_expires abc])[3]).to start_with("[redacted:")
    expect(store.call(%w[2 x hcaptcha_site_key abc])[3]).to start_with("[redacted:")
    expect(fields.call(%w[3 1 slack_webhook_url abc])[3]).to start_with("[redacted:")
    expect(fields.call(%w[4 1 favourite_colour abc])[3]).to eq("abc")
    expect(settings.call(%w[5 min_password_length 10])[2]).to eq("10")
  end

  it "returns nil when a table has nothing to redact" do
    expect(redactor.for("categories", %w[id name slug])).to be_nil
  end

  it "keeps tags stable within a run and differs between runs" do
    expect(redactor.tag("abc")).to eq(redactor.tag("abc"))
    expect(redactor.tag("abc")).not_to eq(redactor.tag("abd"))
    expect(described_class.new.tag("abc")).not_to eq(redactor.tag("abc"))
  end

  it "keeps nil and empty values" do
    redact = redactor.for("users", %w[id password_hash])

    expect(redact.call(["1", nil])).to eq(["1", nil])
    expect(redact.call(["1", ""])).to eq(["1", ""])
  end
end
