require_dependency 'directory_helper'

module Export

  class SchemaArgumentsError < RuntimeError; end

  class JsonEncoder
    attr_accessor :stream_creator

    include DirectoryHelper

    def initialize(stream_creator = nil)
      @stream_creator = stream_creator
      @stream_creator ||= lambda do |filename|
        File.new(filename, 'w+b' )
      end

      @schema_data = {
          schema: {}
      }

      @table_info = {}
    end


    def write_json(name, data)
      filename = File.join( tmp_directory('export'), "#{name}.json")
      filenames << filename
      stream = stream_creator.call(filename)
      Oj.to_stream(stream, data, :mode => :compat)
      stream.close
    end

    def write_schema_info(args)
      raise SchemaArgumentsError unless args[:source].present? && args[:version].present?

      @schema_data[:schema][:source] = args[:source]
      @schema_data[:schema][:version] = args[:version]
    end

    def write_table(table_name, columns)
      rows ||= []

      while true
        current_rows = yield(rows.count)
        break unless current_rows && current_rows.size > 0
        rows.concat current_rows
      end

      # TODO still way too big a chunk, needs to be split up
      write_json(table_name, rows)

      @table_info[table_name] ||= {
        fields: columns.map(&:name),
        row_count: rows.size
      }

    end

    def finish
      @schema_data[:schema][:table_count] = @table_info.keys.count
      write_json("schema", @schema_data.merge(@table_info))
    end

    def filenames
      @filenames ||= []
    end

  end
end
