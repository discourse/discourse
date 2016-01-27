require 'yaml'
require_relative 'quandora_api'

def load_config file
    config = YAML::load_file(File.join(__dir__, file))
    @domain = config['domain']
    @username = config['username']
    @password = config['password']
end

def export
  api = QuandoraApi.new @domain, @username, @password
  bases = api.list_bases
  bases.each do |base|
    question_list = api.list_questions base['objectId'], 1000
    question_list.each do |q|
      question_id = q['uid']
      question = api.get_question question_id
      File.open("output/#{question_id}.json", 'w') do |f|
        puts question['title']
        f.write question.to_json
        f.close
      end
    end
  end
end

load_config ARGV.shift
export

