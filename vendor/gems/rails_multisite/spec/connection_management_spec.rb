require 'spec_helper'
require 'rails_multisite'

class Person < ActiveRecord::Base; end

describe RailsMultisite::ConnectionManagement do

  subject { RailsMultisite::ConnectionManagement }

  def with_connection(db)
    subject.establish_connection(db: db)
    yield ActiveRecord::Base.connection.raw_connection
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  context 'default' do
    its(:all_dbs) { should == ['default']}

    context 'current' do
      before do
        subject.establish_connection(db: 'default')
        ActiveRecord::Base.establish_connection
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

    context 'data partitioning' do
      after do
        ['default','second'].each do |db|
          with_connection(db) do |cnn|
            cnn.execute("drop table people") rescue nil
          end
        end
      end

      it 'partitions data correctly' do
        col1 = []
        col2 = []

        ['default','second'].map do |db|

          with_connection(db) do |cnn|
            cnn.execute("create table if not exists people(id INTEGER PRIMARY KEY AUTOINCREMENT, db)")
          end
        end

        SQLite3::Database.query_log.clear

        5.times do
          ['default','second'].map do |db|
            Thread.new do
              with_connection(db) do |cnn|
                Person.create!(db: db)
              end
            end
          end.map(&:join)
        end

        lists = []
        ['default', 'second'].each do |db|
          with_connection(db) do |cnn|
            lists << Person.order(:id).to_a.map{|p| [p.id, p.db]}
          end
        end

        lists[1].should == (1..5).map{|id| [id, "second"]}
        lists[0].should == (1..5).map{|id| [id, "default"]}

        # puts SQLite3::Database.query_log.map{|args, caller, oid| "#{oid} #{args.join.inspect}"}.join("\n")

      end
    end

  end

end
