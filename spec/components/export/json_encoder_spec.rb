require 'spec_helper'
require 'export/json_encoder'

describe Export::JsonEncoder do
  describe "exported data" do
    before do
      @streams = {}
      @encoder = Export::JsonEncoder.new(lambda{ |filename|
        @streams[File.basename(filename, ".*")] = StringIO.new
      })
    end

    let :schema do
      JSON.parse(@streams['schema'].string)
    end

    describe "write_schema_info" do
      it "should write a schema section when given valid arguments" do
        version = '20121216230719'
        @encoder.write_schema_info( source: 'discourse', version: version )
        @encoder.finish
        schema.should have_key('schema')
        schema['schema']['source'].should == 'discourse'
        schema['schema']['version'].should == version
      end

      it "should raise an exception when its arguments are invalid" do
        expect {
          @encoder.write_schema_info({})
        }.to raise_error(Export::SchemaArgumentsError)
      end
    end

    describe "write_table" do
      let(:table_name) { Topic.table_name }
      let(:columns) { Topic.columns }

      before do
        @encoder.write_schema_info( source: 'discourse', version: '111' )
      end

      it "should yield a row count of 0 to the caller on the first iteration" do
        yield_count = 0
        @encoder.write_table(table_name, columns) do |row_count|
          row_count.should == 0
          yield_count += 1
          break
        end
        yield_count.should == 1
      end

      it "should yield the number of rows I sent the first time on the second iteration" do
        yield_count = 0
        @encoder.write_table(table_name, columns) do |row_count|
          yield_count += 1
          if yield_count == 1
            [[1, 'Hello'], [2, 'Yeah'], [3, 'Great']]
          elsif yield_count == 2
            row_count.should == 3
            break
          end
        end
        yield_count.should == 2
      end

      it "should stop yielding when it gets an empty array" do
        yield_count = 0
        @encoder.write_table(table_name, columns) do |row_count|
          yield_count += 1
          break if yield_count > 1
          []
        end
        yield_count.should == 1
      end

      it "should stop yielding when it gets nil" do
        yield_count = 0
        @encoder.write_table(table_name, columns) do |row_count|
          yield_count += 1
          break if yield_count > 1
          nil
        end
        yield_count.should == 1
      end
    end

    describe "exported data" do
      before do
        @encoder.write_schema_info( source: 'discourse', version: '20121216230719' )
      end

      it "should have a table count of 0 when no tables were exported" do
        @encoder.finish
        schema['schema']['table_count'].should == 0
      end

      it "should have a table count of 1 when one table was exported" do
        @encoder.write_table(Topic.table_name, Topic.columns) { |row_count| [] }
        @encoder.finish
        schema['schema']['table_count'].should == 1
      end

      it "should have a table count of 3 when three tables were exported" do
        @encoder.write_table(Topic.table_name, Topic.columns) { |row_count| [] }
        @encoder.write_table(User.table_name, User.columns)   { |row_count| [] }
        @encoder.write_table(Post.table_name, Post.columns)   { |row_count| [] }
        @encoder.finish
        schema['schema']['table_count'].should == 3
      end

      it "should have a row count of 0 when no rows were exported" do
        @encoder.write_table(Notification.table_name, Notification.columns) { |row_count| [] }
        @encoder.finish
        schema[Notification.table_name]['row_count'].should == 0
      end

      it "should have a row count of 1 when one row was exported" do
        @encoder.write_table(Notification.table_name, Notification.columns) do |row_count|
          if row_count == 0
            [['1409', '5', '1227', '', 't', '2012-12-07 19:59:56.691592', '2012-12-07 19:59:56.691592', '303', '16', '420']]
          else
            []
          end
        end
        @encoder.finish
        schema[Notification.table_name]['row_count'].should == 1
      end

      it "should have a row count of 2 when two rows were exported" do
        @encoder.write_table(Notification.table_name, Notification.columns) do |row_count|
          if row_count == 0
            [['1409', '5', '1227', '', 't', '2012-12-07 19:59:56.691592', '2012-12-07 19:59:56.691592', '303', '16', '420'],
            ['1408', '4', '1188', '', 'f', '2012-12-07 18:40:30.460404', '2012-12-07 18:40:30.460404', '304', '1',  '421']]
          else
            []
          end
        end
        @encoder.finish
        schema[Notification.table_name]['row_count'].should == 2
      end
    end
  end
end
