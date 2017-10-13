require 'rails_helper'

RSpec.describe "Running Sidekiq Jobs in Multisite" do
  let(:conn) { RailsMultisite::ConnectionManagement }

  before do
    conn.config_filename = "spec/fixtures/multisite/two_dbs.yml"
    conn.load_settings!
    conn.remove_class_variable(:@@current_db)
  end

  after do
    conn.clear_settings!

    [:@@db_spec_cache, :@@host_spec_cache, :@@default_spec].each do |class_variable|
      conn.remove_class_variable(class_variable)
    end

    conn.set_current_db
  end

  it 'should revert back to the default connection' do
    expect(RailsMultisite::ConnectionManagement.current_db)
      .to eq('default')

    Jobs::DestroyOldDeletionStubs.new.perform({})

    expect(RailsMultisite::ConnectionManagement.current_db)
      .to eq('default')
  end
end
