# This script pulls translation files from Transifex and ensures they are in the format we need.
# You need the Transifex client installed.
# http://docs.transifex.com/developer/client/setup
#
# Don't use this script to create pull requests. Do translations in Transifex. The Discourse
# team will pull them in.

require 'open3'
require_relative '../lib/locale_file_walker'

if `which tx`.strip.empty?
  puts '', 'The Transifex client needs to be installed to use this script.'
  puts 'Instructions are here: http://docs.transifex.com/client/setup/'
  puts '', 'On Mac:', ''
  puts '  sudo easy_install pip'
  puts '  sudo pip install transifex-client', ''
  exit 1
end

languages = Dir.glob(File.expand_path('../../config/locales/client.*.yml', __FILE__))
              .map { |x| x.split('.')[-2] }.select { |x| x != 'en' }.sort

puts 'Pulling new translations...', ''
command = "tx pull --mode=developer --language=#{languages.join(',')} #{ARGV.include?('force') ? '-f' : ''}"

Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
  while (line = stdout_err.gets)
    puts line
  end
end
puts ''

unless $?.success?
  puts 'Something failed. Check the output above.', ''
  exit $?.exitstatus
end

YML_FILE_COMMENTS = <<END
# encoding: utf-8
#
# Never edit this file. It will be overwritten when translations are pulled from Transifex.
#
# To work with us on translations, join this project:
# https://www.transifex.com/projects/p/discourse-org/
END

YML_DIRS = ['config/locales',
            'plugins/poll/config/locales',
            'vendor/gems/discourse_imgur/lib/discourse_imgur/locale']
YML_FILE_PREFIXES = ['server', 'client']

def yml_path(dir, prefix, language)
  path = "../../#{dir}/#{prefix}.#{language}.yml"
  path = File.expand_path(path, __FILE__)
  File.exists?(path) ? path : nil
end

# Add comments to the top of files and replace the language (first key in YAML file)
def update_file_header(filename, language)
  lines = File.readlines(filename)
  lines.collect! {|line| line =~ /^[a-z_]+:$/i ? "#{language}:" : line}

  File.open(filename, 'w+') do |f|
    f.puts(YML_FILE_COMMENTS, '') unless lines[0][0] == '#'
    f.puts(lines)
  end
end

class YamlAliasFinder < LocaleFileWalker
  def initialize
    @anchors = {}
    @aliases = Hash.new { |hash, key| hash[key] = [] }
  end

  def parse_file(filename)
    document = Psych.parse_file(filename)
    handle_document(document)
    {anchors: @anchors, aliases: @aliases}
  end

  private

  def handle_alias(node, depth, parents)
    @aliases[node.anchor] << parents.dup
  end

  def handle_mapping(node, depth, parents)
    if node.anchor
      @anchors[parents.dup] = node.anchor
    end
  end
end

class YamlAliasSynchronizer < LocaleFileWalker
  def initialize(original_alias_data)
    @anchors = original_alias_data[:anchors]
    @aliases = original_alias_data[:aliases]
    @used_anchors = Set.new

    calculate_required_keys
  end

  def add_to(filename)
    stream = Psych.parse_stream(File.read(filename))
    stream.children.each { |document| handle_document(document) }

    add_aliases
    write_yaml(stream, filename)
  end

  private

  def calculate_required_keys
    @required_keys = {}

    @aliases.each_value do |key_sets|
      key_sets.each do |keys|
        until keys.empty?
          add_needed_node(keys)
          keys = keys.dup
          keys.pop
        end
      end
    end

    add_needed_node([]) unless @required_keys.empty?
  end

  def add_needed_node(keys)
    @required_keys[keys] = {mapping: nil, scalar: nil, alias: nil}
  end

  def write_yaml(stream, filename)
    yaml = stream.to_yaml(nil, {:line_width => -1})

    File.open(filename, 'w') do |file|
      file.write(yaml)
    end
  end

  def handle_scalar(node, depth, parents)
    super(node, depth, parents)

    if @required_keys.has_key?(parents)
      @required_keys[parents][:scalar] = node
    end
  end

  def handle_alias(node, depth, parents)
    if @required_keys.has_key?(parents)
      @required_keys[parents][:alias] = node
    end
  end

  def handle_mapping(node, depth, parents)
    if @anchors.has_key?(parents)
      node.anchor = @anchors[parents]
      @used_anchors.add(node.anchor)
    end

    if @required_keys.has_key?(parents)
      @required_keys[parents][:mapping] = node
    end
  end

  def add_aliases
    @used_anchors.each do |anchor|
      @aliases[anchor].each do |keys|
        parents = []
        parent_node = @required_keys[[]]

        keys.each_with_index do |key, index|
          parents << key
          current_node = @required_keys[parents]
          is_last = index == keys.size - 1
          add_node(current_node, parent_node, key, is_last ? anchor : nil)
          parent_node = current_node
        end
      end
    end
  end

  def add_node(node, parent_node, scalar_name, anchor)
    parent_mapping = parent_node[:mapping]
    parent_mapping.children ||= []

    if node[:scalar].nil?
      node[:scalar] = Psych::Nodes::Scalar.new(scalar_name)
      parent_mapping.children << node[:scalar]
    end

    if anchor.nil?
      if node[:mapping].nil?
        node[:mapping] = Psych::Nodes::Mapping.new
        parent_mapping.children << node[:mapping]
      end
    elsif node[:alias].nil?
      parent_mapping.children << Psych::Nodes::Alias.new(anchor)
    end
  end
end

def get_english_alias_data(dir, prefix)
  filename = yml_path(dir, prefix, 'en')
  filename ? YamlAliasFinder.new.parse_file(filename) : nil
end

def add_anchors_and_aliases(english_alias_data, filename)
  if english_alias_data
    YamlAliasSynchronizer.new(english_alias_data).add_to(filename)
  end
end

YML_DIRS.each do |dir|
  YML_FILE_PREFIXES.each do |prefix|
    english_alias_data = get_english_alias_data(dir, prefix)

    languages.each do |language|
      filename = yml_path(dir, prefix, language)

      if filename
        add_anchors_and_aliases(english_alias_data, filename)
        update_file_header(filename, language)
      end
    end
  end
end
