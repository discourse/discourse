# frozen_string_literal: true

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
    attr_reader :subject_prefix_regex
    attr_reader :automatically_remove_list_name_prefix
    attr_reader :show_trimmed_content
    attr_reader :tags

    def initialize(yaml)
      @data_dir = yaml['data_dir']
      @split_regex = Regexp.new(yaml['split_regex']) unless yaml['split_regex'].empty?
      @batch_size = 1000 # no need to make this actually configurable at the moment
      @trust_level = yaml['default_trust_level']
      @prefer_html = yaml['prefer_html']
      @staged = yaml['staged']
      @index_only = yaml['index_only']
      @group_messages_by_subject = yaml['group_messages_by_subject']

      if yaml['remove_subject_prefixes'].present?
        prefix_regexes = yaml['remove_subject_prefixes'].map { |p| Regexp.new(p) }
        @subject_prefix_regex = /^#{Regexp.union(prefix_regexes).source}/i
      end

      @automatically_remove_list_name_prefix = yaml['automatically_remove_list_name_prefix']
      @show_trimmed_content = yaml['show_trimmed_content']

      @tags = []
      if yaml['tags'].present?
        yaml['tags'].each do |tag_name, value|
          prefixes = Regexp.union(value).source
          @tags << {
            regex: /^(?:(?:\[(?:#{prefixes})\])|(?:\((?:#{prefixes})\)))\s*/i,
            name: tag_name
          }
        end
      end
    end
  end
end
