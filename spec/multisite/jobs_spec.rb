require 'rails_helper'

RSpec.describe "Running Sidekiq Jobs in Multisite" do
  let(:conn) { RailsMultisite::ConnectionManagement }

  before do
    conn.config_filename = "spec/fixtures/multisite/two_dbs.yml"
  end

  after do
    conn.clear_settings!
  end

  it 'should revert back to the default connection' do
    expect(RailsMultisite::ConnectionManagement.current_db)
      .to eq('default')

    Jobs::DestroyOldDeletionStubs.new.perform({})

    expect(RailsMultisite::ConnectionManagement.current_db)
      .to eq('default')
  end
end
