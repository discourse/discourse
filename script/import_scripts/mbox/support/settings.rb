require 'yaml'

module ImportScripts::Mbox
  class Settings
    def self.load(filename)
      yaml = YAML.load_file(filename)
      Settings.new(yaml)
    end

    attr_reader :data_dir
    attr_reader :split_regex
    attr_reader :batch_size
    attr_reader :trust_level
    attr_reader :prefer_html
    attr_reader :staged
    attr_reader :index_only
    attr_reader :group_messages_by_subject

    def initialize(yaml)
      @data_dir = yaml['data_dir']
      @split_regex = Regexp.new(yaml['split_regex']) unless yaml['split_regex'].empty?
      @batch_size = 1000 # no need to make this actually configurable at the moment
      @trust_level = yaml['default_trust_level']
      @prefer_html = yaml['prefer_html']
      @staged = yaml['staged']
      @index_only = yaml['index_only']
      @group_messages_by_subject = yaml['group_messages_by_subject']
    end
  end
end
