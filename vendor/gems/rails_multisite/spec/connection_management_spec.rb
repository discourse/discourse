require 'spec_helper'
require 'rails_multisite'

describe RailsMultisite::ConnectionManagement do

  subject { RailsMultisite::ConnectionManagement }

  context 'default' do
    its(:all_dbs) { should == ['default']}

    context 'current' do
      before do
        subject.establish_connection(db: 'default')
      end

      its(:current_db) { should == 'default' }
      its(:current_hostname) { should == 'default.localhost' }
    end

  end

  context 'two dbs' do

    before do
      subject.config_filename = "spec/fixtures/two_dbs.yml"
      subject.load_settings!
    end
    its(:all_dbs) { should == ['default', 'second']}

    context 'second db' do
      before do
        subject.establish_connection(db: 'second')
      end

      its(:current_db) { should == 'second' }
      its(:current_hostname) { should == "second.localhost" }
    end

  end

end
