module Import

  class JsonDecoder

    def initialize(input_filename)
      @input_filename = input_filename
    end


    def input_stream
      @input_stream ||= begin
        File.open( @input_filename, 'rb' )
      end
    end

    def start( opts )
      @json = JSON.parse(input_stream.read)
      opts[:callbacks][:schema_info].call( source: @json['schema']['source'], version: @json['schema']['version'], table_count: @json.keys.size - 1)
      @json.each do |key, val|
        next if key == 'schema'
        opts[:callbacks][:table_data].call( key, val['fields'], val['rows'], val['row_count'] )
      end
    end

  end

end