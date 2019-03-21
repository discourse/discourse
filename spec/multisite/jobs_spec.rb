require 'rails_helper'

RSpec.describe 'Running Sidekiq Jobs in Multisite', type: :multisite do
  let(:conn) { RailsMultisite::ConnectionManagement }

  it 'should revert back to the default connection' do
    expect { Jobs::DestroyOldDeletionStubs.new.perform({}) }.to_not change do
      RailsMultisite::ConnectionManagement.current_db
    end
  end
end
