require 'spec_helper'
require_dependency 'admin_logger'

describe AdminLogger do

  describe 'new' do
    it 'raises an error when user is nil' do
      expect { AdminLogger.new(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { AdminLogger.new(5) }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe 'log_user_deletion' do
    let(:admin) { Fabricate(:admin) }
    let(:deleted_user) { Fabricate(:user) }

    subject(:log_user_deletion) { AdminLogger.new(admin).log_user_deletion(deleted_user) }

    it 'raises an error when user is nil' do
      expect { AdminLogger.new(admin).log_user_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { AdminLogger.new(admin).log_user_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new AdminLog record' do
      expect { log_user_deletion }.to change { AdminLog.count }.by(1)
    end
  end

end
