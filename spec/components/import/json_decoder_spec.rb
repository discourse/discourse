require 'spec_helper'
require 'import/json_decoder'

describe Import::JsonDecoder do

  describe "start" do
    context "given valid arguments" do
      before do
        @version = '20121201205642'
        @schema = {
          "schema" =>  { 'source' => 'discourse', 'version' => @version},
          "categories" => {
            fields: Category.columns.map(&:name),
            row_count: 2
          },
          "notifications" => {
            fields: Notification.columns.map(&:name),
            row_count: 2
          }
        }

        @categories = [
              ["3", "entertainment", "AB9364", "155", nil, nil, nil, nil, "19", "2012-07-12 18:55:56.355932", "2012-07-12 18:55:56.355932", "1186", "17", "0", "0", "entertainment"],
              ["4", "question", "AB9364", "164", nil, nil, nil, nil, "1", "2012-07-12 18:55:56.355932", "2012-07-12 18:55:56.355932", "1186", "1", "0", "0", "question"]
        ]

        @notifications = [
              ["1416", "2", "1214", "{\"topic_title\":\"UI: Where did the 'Create a Topic' button go?\",\"display_username\":\"Lowell Heddings\"}", "t", "2012-12-09 18:05:09.862898", "2012-12-09 18:05:09.862898", "394", "2", nil],
              ["1415", "2", "1187", "{\"topic_title\":\"Jenkins Config.xml\",\"display_username\":\"Sam\"}", "t", "2012-12-08 10:11:17.599724", "2012-12-08 10:11:17.599724", "392", "3", nil]
            ]

        @decoder = Import::JsonDecoder.new(['xyz/schema.json', 'xyz/categories.json', 'xyz/notifications.json'], lambda{|filename|
          case filename
          when 'xyz/schema.json'
            @schema
          when 'xyz/categories.json'
            @categories
          when 'xyz/notifications.json'
            @notifications
          end
        })


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
          arg["source"].should == @schema["source"]
          arg["version"].should == @schema["version"]
        end
        @decoder.start( @valid_args )
      end

      it "should call the table_data callback at least once for each table in the export file" do
        @valid_args[:callbacks][:table_data].expects(:call).with('categories',
              @schema['categories']['fields'],
              anything, anything
        ).at_least_once

        @valid_args[:callbacks][:table_data].expects(:call).with('notifications',
              @schema['notifications']['fields'], anything, anything).at_least_once
        @decoder.start( @valid_args )
      end
    end

  end

end
