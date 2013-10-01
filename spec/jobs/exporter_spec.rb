require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::Exporter do
  before do
    Jobs::Exporter.any_instance.stubs(:log).returns(true)
    Jobs::Exporter.any_instance.stubs(:create_tar_file).returns(true)
    Export::JsonEncoder.any_instance.stubs(:tmp_directory).returns( File.join(Rails.root, 'tmp', 'exporter_spec') )
    Discourse.stubs(:enable_maintenance_mode).returns(true)
    Discourse.stubs(:disable_maintenance_mode).returns(true)
  end

  describe "execute" do
    context 'when no export or import is running' do
      before do
        @testIO = StringIO.new
        Export::JsonEncoder.any_instance.stubs(:json_output_stream).returns(@testIO)
        Jobs::Exporter.any_instance.stubs(:ordered_models_for_export).returns([])
        Export.stubs(:is_export_running?).returns(false)
        Export.stubs(:is_import_running?).returns(false)
        @exporter_args = {}
      end

      it "should indicate that an export is running" do
        seq = sequence('call sequence')
        Export.expects(:set_export_started).in_sequence(seq).at_least_once
        Export.expects(:set_export_is_not_running).in_sequence(seq).at_least_once
        Jobs::Exporter.new.execute( @exporter_args )
      end

      it "should put the site in maintenance mode when it starts" do
        encoder = stub_everything
        Export::JsonEncoder.stubs(:new).returns(encoder)
        seq = sequence('export-sequence')
        Discourse.expects(:enable_maintenance_mode).in_sequence(seq).at_least_once
        encoder.expects(:write_schema_info).in_sequence(seq).at_least_once
        Jobs::Exporter.new.execute( @exporter_args )
      end

      it "should take the site out of maintenance mode when it ends" do
        encoder = stub_everything
        Export::JsonEncoder.stubs(:new).returns(encoder)
        seq = sequence('export-sequence')
        encoder.expects(:write_schema_info).in_sequence(seq).at_least_once
        Discourse.expects(:disable_maintenance_mode).in_sequence(seq).at_least_once
        Jobs::Exporter.new.execute( @exporter_args )
      end

      describe "without specifying a format" do
        it "should use json as the default" do
          Export::JsonEncoder.expects(:new).returns( stub_everything )
          Jobs::Exporter.new.execute( @exporter_args.reject { |key, val| key == :format } )
        end
      end

      describe "specifying an invalid format" do
        it "should raise an exception and not flag that an export has started" do
          Jobs::Exporter.expects(:set_export_started).never
          expect {
            Jobs::Exporter.new.execute( @exporter_args.merge( format: :interpretive_dance ) )
          }.to raise_error(Export::FormatInvalidError)
        end
      end

      context "using json format" do
        before do
          @exporter_args = {format: :json}
        end

        it "should export metadata" do
          version = '201212121212'
          encoder = stub_everything
          encoder.expects(:write_schema_info).with do |arg|
            arg[:source].should == 'discourse'
            arg[:version].should == version
          end
          Export::JsonEncoder.stubs(:new).returns(encoder)
          Export.stubs(:current_schema_version).returns(version)
          Jobs::Exporter.new.execute( @exporter_args )
        end

        describe "exporting tables" do
          before do
            # Create some real database records
            @user1, @user2 = Fabricate(:user), Fabricate(:user)
            @topic1 = Fabricate(:topic, user: @user1)
            @topic2 = Fabricate(:topic, user: @user2)
            @topic3 = Fabricate(:topic, user: @user1)
            @post1 = Fabricate(:post, topic: @topic1, user: @user1)
            @post1 = Fabricate(:post, topic: @topic3, user: @user1)
            @reply1 = Fabricate(:basic_reply, user: @user2, topic: @topic3)
            @reply1.save_reply_relationships
            @reply2 = Fabricate(:basic_reply, user: @user1, topic: @topic1)
            @reply2.save_reply_relationships
            @reply3 = Fabricate(:basic_reply, user: @user1, topic: @topic3)
            @reply3.save_reply_relationships
          end

          it "should export all rows from the topics table in ascending id order" do
            Jobs::Exporter.any_instance.stubs(:ordered_models_for_export).returns([Topic])
            Jobs::Exporter.new.execute( @exporter_args )
            json = JSON.parse( @testIO.string )
            json.should have_key('topics')
            json['topics'].should have_key('rows')
            json['topics']['rows'].should have(3).rows
            json['topics']['rows'][0][0].to_i.should == @topic1.id
            json['topics']['rows'][1][0].to_i.should == @topic2.id
            json['topics']['rows'][2][0].to_i.should == @topic3.id
          end

          it "should export all rows from the post_replies table in ascending order by post_id, reply_id" do
            # because post_replies doesn't have an id column, so order by one of its indexes
            Jobs::Exporter.any_instance.stubs(:ordered_models_for_export).returns([PostReply])
            Jobs::Exporter.new.execute( @exporter_args )
            json = JSON.parse( @testIO.string )
            json.should have_key('post_replies')
            json['post_replies'].should have_key('rows')
            json['post_replies']['rows'].should have(3).rows
            json['post_replies']['rows'][0][1].to_i.should == @reply2.id
            json['post_replies']['rows'][1][1].to_i.should == @reply1.id
            json['post_replies']['rows'][2][1].to_i.should == @reply3.id
          end

          it "should export column names for each table" do
            Jobs::Exporter.any_instance.stubs(:ordered_models_for_export).returns([Topic, TopicUser, PostReply])
            Jobs::Exporter.new.execute( @exporter_args )
            json = JSON.parse( @testIO.string )
            json['topics'].should have_key('fields')
            json['topic_users'].should have_key('fields')
            json['post_replies'].should have_key('fields')
            json['topics']['fields'].should == Topic.columns.map(&:name)
            json['topic_users']['fields'].should == TopicUser.columns.map(&:name)
            json['post_replies']['fields'].should == PostReply.columns.map(&:name)
          end
        end
      end

      context "when it finishes successfully" do
        context "and no user was given" do
          it "should not send a notification to anyone" do
            expect {
              Jobs::Exporter.new.execute( @exporter_args )
            }.to_not change { Notification.count }
          end
        end

        context "and a user was given" do
          before do
            @user = Fabricate(:user)
            @admin = Fabricate(:admin)
          end

          it "should send a notification to the user who started the export" do

            ActiveRecord::Base.observers.enable :all
            expect {
              Jobs::Exporter.new.execute( @exporter_args.merge( user_id: @user.id ) )
            }.to change { Notification.count }.by(1)
          end
        end
      end
    end

    context 'when an export is already running' do
      before do
        Export.expects(:is_export_running?).returns(true)
      end

      it "should not start an export and raise an exception" do
        Export.expects(:set_export_started).never
        Jobs::Exporter.any_instance.expects(:start_export).never
        expect {
          Jobs::Exporter.new.execute({})
        }.to raise_error(Export::ExportInProgressError)
      end
    end

    context 'when an import is running' do
      before do
        Import.expects(:is_import_running?).returns(true)
      end

      it "should not start an export and raise an exception" do
        Export.expects(:set_export_started).never
        Jobs::Exporter.any_instance.expects(:start_export).never
        expect {
          Jobs::Exporter.new.execute({})
        }.to raise_error(Import::ImportInProgressError)
      end
    end
  end

end
