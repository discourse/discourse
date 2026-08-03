# frozen_string_literal: true

require Rails.root.join("db/migrate/20260629210246_revoke_invalid_read_only_api_keys.rb")

RSpec.describe RevokeInvalidReadOnlyApiKeys do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "revokes invalid active read-only API keys" do
    invalid_key_id = insert_api_key(scope_mode: 1)
    valid_key_id = insert_api_key(scope_mode: 1)
    add_scope(valid_key_id, "global", "read")
    extra_scope_key_id = insert_api_key(scope_mode: 1)
    add_scope(extra_scope_key_id, "global", "read")
    add_scope(extra_scope_key_id, "topics", "write")
    wrong_scope_key_id = insert_api_key(scope_mode: 1)
    add_scope(wrong_scope_key_id, "topics", "read")
    global_key_id = insert_api_key(scope_mode: 0)
    revoked_invalid_key_id = insert_api_key(scope_mode: 1, revoked_at: true)

    described_class.new.migrate(:up)

    expect(ApiKey.find(invalid_key_id).revoked_at).to be_present
    expect(ApiKey.find(valid_key_id).revoked_at).to be_nil
    expect(ApiKey.find(extra_scope_key_id).revoked_at).to be_present
    expect(ApiKey.find(wrong_scope_key_id).revoked_at).to be_present
    expect(ApiKey.find(global_key_id).revoked_at).to be_nil
    expect(ApiKey.find(revoked_invalid_key_id).revoked_at).to be_present
  end

  def insert_api_key(scope_mode:, revoked_at: false)
    DB.query_single(<<~SQL).first
      INSERT INTO api_keys (key_hash, truncated_key, scope_mode, revoked_at, created_at, updated_at)
      VALUES (
        '#{SecureRandom.hex(32)}',
        'abcd',
        #{scope_mode},
        #{revoked_at ? "CURRENT_TIMESTAMP" : "NULL"},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      RETURNING id
    SQL
  end

  def add_scope(api_key_id, resource, action)
    DB.exec(<<~SQL)
      INSERT INTO api_key_scopes (api_key_id, resource, action, created_at, updated_at)
      VALUES (#{api_key_id}, '#{resource}', '#{action}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end
end
