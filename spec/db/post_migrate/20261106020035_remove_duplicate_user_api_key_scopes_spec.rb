# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20261106020035_remove_duplicate_user_api_key_scopes.rb")

RSpec.describe RemoveDuplicateUserApiKeyScopes do
  fab!(:user_api_key)
  fab!(:other_user_api_key, :user_api_key)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def add_scope(key, name, allowed_parameters = nil)
    Fabricate(
      :user_api_key_scope,
      user_api_key_id: key.id,
      name: name,
      allowed_parameters: allowed_parameters,
    )
  end

  it "keeps one row per scope of a key, including its allowed parameters" do
    read = add_scope(user_api_key, "read")
    add_scope(user_api_key, "read")
    notifications = add_scope(user_api_key, "notifications", { "topic_id" => ["1"] })
    add_scope(user_api_key, "notifications", { "topic_id" => ["1"] })
    other_notifications = add_scope(user_api_key, "notifications", { "topic_id" => ["2"] })
    other_key_read = add_scope(other_user_api_key, "read")

    described_class.new.up

    expect(UserApiKeyScope.pluck(:id)).to contain_exactly(
      read.id,
      notifications.id,
      other_notifications.id,
      other_key_read.id,
    )
  end
end
