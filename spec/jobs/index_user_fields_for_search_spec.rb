# frozen_string_literal: true

RSpec.describe Jobs::IndexUserFieldsForSearch do
  subject(:job) { described_class.new }

  before do
    SearchIndexer.enable
    Jobs.run_immediately!
  end

  it "triggers a reindex when executed" do
    user = Fabricate(:user)
    user_field = Fabricate(:user_field)
    Fabricate(:user_custom_field, user: user, name: "user_field_#{user_field.id}")

    job.execute(user_field_id: user_field.id)

    expect(user.reload.user_search_data.version).to eq(SearchIndexer::REINDEX_VERSION)
  end
end
