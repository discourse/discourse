module Import

  class JsonDecoder

    def initialize(filenames, loader = nil)
      @filemap = Hash[*
        filenames.map do |filename|
          [File.basename(filename, '.*'), filename]
        end.flatten
      ]
      @loader = loader || lambda{|filename| Oj.load_file(filename)}
    end

    def load_schema
      @loader.call(@filemap['schema'])
    end

    def each_table
      @filemap.each do |name, filename|
        next if name == 'schema'
        yield name, @loader.call(filename)
      end
    end


    def input_stream
      @input_stream ||= begin
      end
    end

    def start( opts )
      schema = load_schema
      opts[:callbacks][:schema_info].call( source: schema['schema']['source'], version: schema['schema']['version'], table_count: schema.keys.size - 1)

      each_table do |name, data|
        info = schema[name]
        opts[:callbacks][:table_data].call( name, info['fields'], data, info['row_count'] )
      end
    end

  end

end
