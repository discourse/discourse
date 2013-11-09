require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::Importer do
  def stub_schema_changes
    Jobs::Importer.any_instance.stubs(:create_backup_schema).returns( true )
    Jobs::Importer.any_instance.stubs(:backup_and_setup_table).returns( true )
  end

  def stub_data_loading
    Jobs::Importer.any_instance.stubs(:set_schema_info).returns( true )
    Jobs::Importer.any_instance.stubs(:load_table).returns( true )
    Jobs::Importer.any_instance.stubs(:create_indexes).returns( true )
  end

  before do
    Discourse.stubs(:enable_maintenance_mode).returns(true)
    Discourse.stubs(:disable_maintenance_mode).returns(true)
    Jobs::Importer.any_instance.stubs(:log).returns(true)
    Jobs::Importer.any_instance.stubs(:extract_uploads).returns(true)
    Jobs::Importer.any_instance.stubs(:extract_files).returns(true)
    Jobs::Importer.any_instance.stubs(:tmp_directory).returns( File.join(Rails.root, 'tmp', 'importer_spec') )
    @importer_args = { filename: 'importer_spec.json.gz' }
  end

  context "SiteSetting to enable imports" do
    it "should exist" do
      SiteSetting.all_settings.detect {|s| s[:setting] == :allow_import }.should be_present
    end

    it "should default to false" do
      SiteSetting.allow_import?.should be_false
    end
  end

  context 'when import is disabled' do
    before do
      stub_schema_changes
      stub_data_loading
      Import::JsonDecoder.stubs(:new).returns( stub_everything )
      SiteSetting.stubs(:allow_import).returns(false)
    end

    describe "execute" do
      it "should raise an error" do
        expect {
          Jobs::Importer.new.execute( @importer_args )
        }.to raise_error(Import::ImportDisabledError)
      end

      it "should not start an import" do
        Import::JsonDecoder.expects(:new).never
        Jobs::Importer.any_instance.expects(:backup_tables).never
        Discourse.expects(:enable_maintenance_mode).never
        Jobs::Importer.new.execute( @importer_args ) rescue nil
      end
    end
  end

  context 'when import is enabled' do
    before do
      SiteSetting.stubs(:allow_import).returns(true)
    end

    describe "execute" do
      before do
        stub_data_loading
      end

      shared_examples_for "when import should not be started" do
        it "should not start an import" do
          Import::JsonDecoder.expects(:new).never
          Jobs::Importer.any_instance.expects(:backup_tables).never
          Jobs::Importer.new.execute( @invalid_args ) rescue nil
        end

        it "should not put the site in maintenance mode" do
          Discourse.expects(:enable_maintenance_mode).never
          Jobs::Importer.new.execute( @invalid_args ) rescue nil
        end
      end

      context "when an import is already running" do
        before do
          Import::JsonDecoder.stubs(:new).returns( stub_everything )
          Import.stubs(:is_import_running?).returns( true )
        end

        it "should raise an error" do
          expect {
            Jobs::Importer.new.execute( @importer_args )
          }.to raise_error(Import::ImportInProgressError)
        end

        it_should_behave_like "when import should not be started"
      end

      context "when an export is running" do
        before do
          Export.stubs(:is_export_running?).returns( true )
        end

        it "should raise an error" do
          expect {
            Jobs::Importer.new.execute( @importer_args )
          }.to raise_error(Export::ExportInProgressError)
        end

        it_should_behave_like "when import should not be started"
      end

      context "when no export or import are running" do
        before do
          Import.stubs(:is_import_running?).returns( false )
          Export.stubs(:is_export_running?).returns( false )
        end

        it "without specifying a format should use json as the default format" do
          stub_schema_changes
          Import::JsonDecoder.expects(:new).returns( stub_everything )
          Jobs::Importer.new.execute( @importer_args.reject { |key, val| key == :format } )
        end

        it "when specifying json as the format it should use json" do
          stub_schema_changes
          Import::JsonDecoder.expects(:new).returns( stub_everything )
          Jobs::Importer.new.execute( @importer_args.merge(format: :json) )
        end

        context "when specifying an invalid format" do
          before do
            stub_schema_changes
            @invalid_args = @importer_args.merge( format: :smoke_signals )
          end

          it "should raise an error" do
            expect {
              Jobs::Importer.new.execute( @invalid_args )
            }.to raise_error(Import::FormatInvalidError)
          end

          it_should_behave_like "when import should not be started"
        end

        context "when filename is not given" do
          before do
            stub_schema_changes
            @invalid_args = @importer_args.reject { |k,v| k == :filename }
          end

          it "should raise an error" do
            expect {
              Jobs::Importer.new.execute( @invalid_args )
            }.to raise_error(Import::FilenameMissingError)
          end

          it_should_behave_like "when import should not be started"
        end

        context "before loading data into tables" do
          before do
            Import::JsonDecoder.stubs(:new).returns( stub_everything )
            stub_data_loading
          end

          shared_examples_for "a successful call to execute" do
            it "should make a backup of the users table" do
              Jobs::Importer.any_instance.stubs(:ordered_models_for_import).returns([User])
              Jobs::Importer.new.execute(@importer_args)
              User.exec_sql_row_count("SELECT table_name FROM information_schema.tables WHERE table_schema = 'backup' AND table_name = 'users'").should == 1
            end

            # Neil, please have a look here
            it "should have a users table that's empty" do
              @user1 = Fabricate(:user)
              Jobs::Importer.any_instance.stubs(:ordered_models_for_import).returns([User])
              Jobs::Importer.new.execute(@importer_args)
              User.count.should == 0 # empty table (data loading is stubbed for this test)
            end

            it "should indicate that an import is running" do
              seq = sequence('call sequence')
              Import.expects(:set_import_started).in_sequence(seq).at_least_once
              Import.expects(:set_import_is_not_running).in_sequence(seq).at_least_once
              Jobs::Importer.new.execute(@importer_args)
            end

            it "should put the site in maintenance mode" do
              seq = sequence('call sequence')
              Import.is_import_running?.should be_false
              Discourse.expects(:enable_maintenance_mode).in_sequence(seq).at_least_once
              Jobs::Importer.any_instance.expects(:backup_tables).in_sequence(seq).at_least_once
              Jobs::Importer.any_instance.expects(:load_data).in_sequence(seq).at_least_once
              Jobs::Importer.new.execute( @importer_args )
            end

            it "should take the site out of maintenance mode when it's done" do
              seq = sequence('call sequence')
              Jobs::Importer.any_instance.expects(:backup_tables).in_sequence(seq).at_least_once
              Jobs::Importer.any_instance.expects(:load_data).in_sequence(seq).at_least_once
              Discourse.expects(:disable_maintenance_mode).in_sequence(seq).at_least_once
              Jobs::Importer.new.execute( @importer_args )
            end
          end

          context "the first time an import is run" do
            it_should_behave_like "a successful call to execute"
          end

          context "the second time an import is run" do
            before do
              Jobs::Importer.new.execute(@importer_args)
            end
            it_should_behave_like "a successful call to execute"
          end
        end

        #
        # Import notifications don't work from the rake task.  Why is activerecord inserting an "id" value of NULL?
        #
        #   PG::Error: ERROR:  null value in column "id" violates not-null constraint
        #   : INSERT INTO "topic_allowed_users" ("created_at", "id", "topic_id", "updated_at", "user_id") VALUES ($1, $2, $3, $4, $5) RETURNING "id"
        #

        # context "when it finishes successfully" do
        #   before do
        #     stub_schema_changes
        #     Import::JsonDecoder.stubs(:new).returns( stub_everything )
        #   end

        #   context "and no user was given" do
        #     it "should not send a notification to anyone" do
        #       expect {
        #         Jobs::Importer.new.execute( @importer_args )
        #       }.to_not change { Notification.count }
        #     end
        #   end

        #   context "and a user was given" do
        #     before do
        #       @user = Fabricate(:user)
        #       @admin = Fabricate(:admin)
        #     end

        #     it "should send a notification to the user who started the import" do
        #       expect {
        #         Jobs::Importer.new.execute( @importer_args.merge( user_id: @user.id ) )
        #       }.to change { Notification.count }.by(1)
        #     end
        #   end
        # end
      end
    end

    describe "set_schema_info" do
      context "when source is Discourse" do
        before do
          @current_version = '20121216230719'
          Export.stubs(:current_schema_version).returns(@current_version)
          @valid_args = { source: 'discourse', version: @current_version, table_count: Export.models_included_in_export.size }
        end

        it "succeeds when receiving the current schema version" do
          Jobs::Importer.new.set_schema_info( @valid_args ).should be_true
        end

        it "succeeds when receiving an older schema version" do
          Jobs::Importer.new.set_schema_info( @valid_args.merge( version: "#{@current_version.to_i - 1}") ).should be_true
        end

        it "raises an error if version is not given" do
          expect {
            Jobs::Importer.new.set_schema_info( @valid_args.reject {|key, val| key == :version} )
          }.to raise_error(ArgumentError)
        end

        it "raises an error when receiving a newer schema version" do
          expect {
            Jobs::Importer.new.set_schema_info( @valid_args.merge( version: "#{@current_version.to_i + 1}") )
          }.to raise_error(Import::UnsupportedSchemaVersion)
        end

        it "raises an error when it doesn't get the number of tables it expects" do
          expect {
            Jobs::Importer.new.set_schema_info( @valid_args.merge( table_count: 2 ) )
          }.to raise_error(Import::WrongTableCountError)
        end
      end

      it "raises an error when it receives an unsupported source" do
        expect {
          Jobs::Importer.new.set_schema_info( source: 'digg' )
        }.to raise_error(Import::UnsupportedExportSource)
      end
    end

    describe "load_table" do
      before do
        stub_schema_changes
        @valid_field_list = ["id", "notification_type", "user_id", "data", "read", "created_at", "updated_at", "topic_id", "post_number", "post_action_id"]
        @valid_notifications_row_data = [
          ['1409', '5', '1227', '', 't', '2012-12-07 19:59:56.691592', '2012-12-07 19:59:56.691592', '303', '16', '420'],
          ['1408', '4', '1188', '', 'f', '2012-12-07 18:40:30.460404', '2012-12-07 18:40:30.460404', '304', '1',  '421']
        ]
      end

      context "when export data is at the current scheam version" do
        before do
          Import.stubs(:adapters_for_version).returns({})
        end

        context "with good data" do
          it "should add rows to the notifcations table given valid row data" do
            Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            Notification.count.should == @valid_notifications_row_data.length
          end

          it "should successfully load rows with double quote literals in the values" do
            @valid_notifications_row_data[0][3] = "{\"topic_title\":\"Errors, errbit and you!\",\"display_username\":\"Coding Horror\"}"
            Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            Notification.count.should == @valid_notifications_row_data.length
          end

          it "should successfully load rows with single quote literals in the values" do
            @valid_notifications_row_data[0][3] = "{\"topic_title\":\"Bacon's Delicious, Am I Right\",\"display_username\":\"Celine Dion\"}"
            Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            Notification.count.should == @valid_notifications_row_data.length
          end

          it "should succesfully load rows with null values" do
            @valid_notifications_row_data[0][7] = nil
            @valid_notifications_row_data[1][9] = nil
            Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            Notification.count.should == @valid_notifications_row_data.length
          end

          it "should successfully load rows with question marks in the values" do
            @valid_notifications_row_data[0][3] = "{\"topic_title\":\"Who took my sandwich?\",\"display_username\":\"Lunchless\"}"
            Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            Notification.count.should == @valid_notifications_row_data.length
          end
        end

        context "with fewer than the expected number of fields for a table" do
          before do
            @short_field_list = ["id", "notification_type", "user_id", "data", "read", "created_at", "updated_at", "topic_id", "post_number"]
            @short_notifications_row_data = [
              ['1409', '5', '1227', '', 't', '2012-12-07 19:59:56.691592', '2012-12-07 19:59:56.691592', '303', '16'],
              ['1408', '4', '1188', '', 'f', '2012-12-07 18:40:30.460404', '2012-12-07 18:40:30.460404', '304', '1']
            ]
          end

          it "should not raise an error" do
            expect {
              Jobs::Importer.new.load_table('notifications', @short_field_list, @short_notifications_row_data, @short_notifications_row_data.size)
            }.to_not raise_error
          end
        end

        context "with more than the expected number of fields for a table" do
          before do
            @too_long_field_list = ["id", "notification_type", "user_id", "data", "read", "created_at", "updated_at", "topic_id", "post_number", "post_action_id", "extra_col"]
            @too_long_notifications_row_data = [
              ['1409', '5', '1227', '', 't', '2012-12-07 19:59:56.691592', '2012-12-07 19:59:56.691592', '303', '16', '420', 'extra'],
              ['1408', '4', '1188', '', 'f', '2012-12-07 18:40:30.460404', '2012-12-07 18:40:30.460404', '304', '1',  '421', 'extra']
            ]
          end

          it "should raise an error" do
            expect {
              Jobs::Importer.new.load_table('notifications', @too_long_field_list, @too_long_notifications_row_data, @too_long_notifications_row_data.size)
            }.to raise_error(Import::WrongFieldCountError)
          end
        end

        context "with an unrecognized table name" do
          it "should not raise an error" do
            expect {
              Jobs::Importer.new.load_table('pork_chops', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
            }.to_not raise_error
          end

          it "should report a warning" do
            Jobs::Importer.any_instance.expects(:add_warning).once
            Jobs::Importer.new.load_table('pork_chops', @valid_field_list, @valid_notifications_row_data, @valid_notifications_row_data.size)
          end
        end
      end

      context "when import adapters are needed" do
        before do
          @version = (Export.current_schema_version.to_i - 1).to_s
          Export.stubs(:current_schema_version).returns( @version )
        end

        it "should apply the adapter" do
          @adapter = mock('adapter', apply_to_column_names: @valid_field_list, apply_to_row: @valid_notifications_row_data[0])
          Import.expects(:adapters_for_version).at_least_once.returns({'notifications' => [@adapter]})
          Jobs::Importer.new.load_table('notifications', @valid_field_list, @valid_notifications_row_data[0,1], 1)
        end
      end
    end

    describe "create_indexes" do
      before do
        Import::JsonDecoder.stubs(:new).returns( stub_everything )
        Jobs::Importer.any_instance.stubs(:set_schema_info).returns( true )
        Jobs::Importer.any_instance.stubs(:load_table).returns( true )
      end

      it "should create the same indexes on the new tables" do
        Jobs::Importer.any_instance.stubs(:ordered_models_for_import).returns([Topic])
        expect {
          Jobs::Importer.new.execute( @importer_args )
        }.to_not change{ Topic.exec_sql("SELECT indexname FROM pg_indexes WHERE tablename = 'topics' and schemaname = 'public';").map {|x| x['indexname']}.sort }
      end

      it "should create primary keys" do
        Jobs::Importer.any_instance.stubs(:ordered_models_for_import).returns([User])
        Jobs::Importer.new.execute( @importer_args )
        User.connection.primary_key('users').should_not be_nil
      end
    end

    describe "rollback" do
      it "should not get called if format parameter is invalid" do
        stub_data_loading
        Jobs::Importer.any_instance.stubs(:start_import).raises(Import::FormatInvalidError)
        Jobs::Importer.any_instance.expects(:rollback).never
        Jobs::Importer.new.execute( @importer_args ) rescue nil
      end

      context "when creating the backup schema fails" do
        it "should not call rollback" do
          stub_data_loading
          Jobs::Importer.any_instance.stubs(:create_backup_schema).raises(RuntimeError)
          Jobs::Importer.any_instance.expects(:rollback).never
          Jobs::Importer.new.execute( @importer_args ) rescue nil
        end
      end

      shared_examples_for "a case when rollback is needed" do
        before do
          Jobs::Importer.any_instance.stubs(:ordered_models_for_import).returns([User])
          @user1, @user2 = Fabricate(:user), Fabricate(:user)
          @user_row1 = User.connection.select_rows("select * from users order by id DESC limit 1")
          @user_row1[0] = '11111' # change the id
          @export_data = {
            schema: { source: 'discourse', version: '20121201205642'},
            users: {
              fields: User.columns.map(&:name),
              rows: [ *@user_row1 ]
            }
          }
          @testIO = StringIO.new(@export_data.to_json, 'r')
          Import::JsonDecoder.any_instance.stubs(:input_stream).returns(@testIO)
        end

        it "should call rollback" do
          Jobs::Importer.any_instance.expects(:rollback).once
          Jobs::Importer.new.execute( @importer_args ) rescue nil
        end

        it "should restore the data" do
          expect {
            Jobs::Importer.new.execute( @importer_args ) rescue nil
          }.to_not change { User.count }
          users = User.all
          users.should include(@user1)
          users.should include(@user2)
        end

        it "should take the site out of maintenance mode" do
          Discourse.expects(:disable_maintenance_mode).at_least_once
          Jobs::Importer.new.execute( @importer_args ) rescue nil
        end
      end

      context "when backing up a table fails" do
        it "should not call rollback" do # because the transaction will rollback automatically
          stub_data_loading
          Jobs::Importer.any_instance.stubs(:backup_and_setup_table).raises(ActiveRecord::StatementInvalid)
          Jobs::Importer.any_instance.expects(:rollback).never
          Jobs::Importer.new.execute( @importer_args ) rescue nil
        end
      end

      context "when export source is invalid" do
        before do
          Jobs::Importer.any_instance.stubs(:set_schema_info).raises(Import::UnsupportedExportSource)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when schema version is not supported" do
        before do
          Jobs::Importer.any_instance.stubs(:set_schema_info).raises(Import::UnsupportedSchemaVersion)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when schema info in export file is invalid for some other reason" do
        before do
          Jobs::Importer.any_instance.stubs(:set_schema_info).raises(ArgumentError)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when loading a table fails" do
        before do
          Jobs::Importer.any_instance.stubs(:load_table).raises(ActiveRecord::StatementInvalid)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when creating indexes fails" do
        before do
          Jobs::Importer.any_instance.stubs(:create_indexes).raises(ActiveRecord::StatementInvalid)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when table count is wrong" do
        before do
          Jobs::Importer.any_instance.stubs(:set_schema_info).raises(Import::WrongTableCountError)
        end
        it_should_behave_like "a case when rollback is needed"
      end

      context "when field count for a table is wrong" do
        before do
          Jobs::Importer.any_instance.stubs(:load_table).raises(Import::WrongFieldCountError)
        end
        it_should_behave_like "a case when rollback is needed"
      end
    end
  end
end
