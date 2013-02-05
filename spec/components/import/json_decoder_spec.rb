require 'spec_helper'
require 'import/json_decoder'

describe Import::JsonDecoder do

  describe "start" do
    context "given valid arguments" do
      before do
        @version = '20121201205642'
        @export_data = {
          schema: { source: 'discourse', version: @version},
          categories: {
            fields: Category.columns.map(&:name),
            rows: [
              ["3", "entertainment", "AB9364", "155", nil, nil, nil, nil, "19", "2012-07-12 18:55:56.355932", "2012-07-12 18:55:56.355932", "1186", "17", "0", "0", "entertainment"],
              ["4", "question", "AB9364", "164", nil, nil, nil, nil, "1", "2012-07-12 18:55:56.355932", "2012-07-12 18:55:56.355932", "1186", "1", "0", "0", "question"]
            ]
          },
          notifications: {
            fields: Notification.columns.map(&:name),
            rows: [
              ["1416", "2", "1214", "{\"topic_title\":\"UI: Where did the 'Create a Topic' button go?\",\"display_username\":\"Lowell Heddings\"}", "t", "2012-12-09 18:05:09.862898", "2012-12-09 18:05:09.862898", "394", "2", nil],
              ["1415", "2", "1187", "{\"topic_title\":\"Jenkins Config.xml\",\"display_username\":\"Sam\"}", "t", "2012-12-08 10:11:17.599724", "2012-12-08 10:11:17.599724", "392", "3", nil]
            ]
          }
        }
        @testIO = StringIO.new(@export_data.to_json, 'r')
        @decoder = Import::JsonDecoder.new('json_decoder_spec.json.gz')
        @decoder.stubs(:input_stream).returns(@testIO)
        @valid_args = { callbacks: { schema_info: stub_everything, table_data: stub_everything } }
      end

      it "should call the schema_info callback before sending table data" do
        callback_sequence = sequence('callbacks')
        @valid_args[:callbacks][:schema_info].expects(:call).in_sequence(callback_sequence)
        @valid_args[:callbacks][:table_data].expects(:call).in_sequence(callback_sequence).at_least_once
        @decoder.start( @valid_args )
      end

      it "should call the schema_info callback with source and version parameters when export data is from discourse" do
        @valid_args[:callbacks][:schema_info].expects(:call).with do |arg|
          arg.should have_key(:source)
          arg.should have_key(:version)
          arg[:source].should == @export_data[:schema][:source]
          arg[:version].should == @export_data[:schema][:version]
        end
        @decoder.start( @valid_args )
      end

      it "should call the table_data callback at least once for each table in the export file" do
        @valid_args[:callbacks][:table_data].expects(:call).with('categories',    @export_data[:categories][:fields],    anything, anything).at_least_once
        @valid_args[:callbacks][:table_data].expects(:call).with('notifications', @export_data[:notifications][:fields], anything, anything).at_least_once
        @decoder.start( @valid_args )
      end
    end

    context "given invalid arguments" do

    end
  end

end