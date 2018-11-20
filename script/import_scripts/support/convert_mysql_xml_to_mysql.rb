# convert huge XML dump to mysql friendly import
#

require 'ox'
require 'set'

class Saxy < Ox::Sax

  def initialize
    @stack = []
  end

  def start_element(name)
    @stack << { elem: name }
  end

  def end_element(name)
    @stack.pop
  end

  def attr(name, value)
    return unless @stack[-1]
    (@stack[-1][:attrs] ||= {})[name] = value
  end

  def text(val)
    @stack[-1][:text] = val
  end

  def cdata(val)
    @stack[-1][:text] = val
  end

end

class Convert < Saxy
  def initialize(opts)
    @tables = {}
    @skip_data = Set.new(opts[:skip_data])
    super()
  end

  def end_element(name)
    old = @stack.pop
    cur = @stack[-1]

    if name == :field && cur[:elem] == :row
      (cur[:row_data] ||= {})[old[:attrs][:name]] = old[:text]
    elsif name == :row && cur[:elem] == :table_data
      create_insert_statement(old)
    elsif name == :field && cur[:elem] == :table_structure
      (cur[:cols] ||= []) << old
    elsif name == :table_structure
      output_table_definition(old)
      @tables[old[:name]] = old
    end
  end

  def output_table_definition(data)
    cols = data[:cols].map do |col|
      attrs = col[:attrs]
      "#{attrs[:Field]} #{attrs[:Type]}"
    end.join(", ")
    puts "CREATE TABLE #{data[:attrs][:name]} (#{cols});"
  end

  def create_insert_statement(data)
    name = @stack[-1][:attrs][:name]
    return if @skip_data.include?(name)

    row = data[:row_data]
    col_names = row.keys.join(",")
    vals = row.values.map { |v| "'#{v.gsub("'", "''").gsub('\\', '\\\\\\')}'" }.join(",")
    puts "INSERT INTO #{name} (#{col_names}) VALUES (#{vals});"
  end
end

Ox.sax_parse(Convert.new(skip_data: ['metrics2', 'user_log']), File.open(ARGV[0]))
