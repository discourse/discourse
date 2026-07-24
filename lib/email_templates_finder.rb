# frozen_string_literal: true

class EmailTemplatesFinder
  def self.list
    path = Rails.root.join("config/locales/server.en.yml").to_s
    yaml = YAML.load_file(path, aliases: true)
    new(yaml).list
  end

  attr_reader :list

  def initialize(obj)
    @obj = obj
    @list = []
    check(@obj, "")
    @list.sort!
  end

  private

  def check(obj, path)
    obj.each do |key, val|
      if Hash === val
        next_path = "#{path}#{key}"
        if val.key?("text_body_template") && val.key?("subject_template")
          @list << next_path.sub("en.", "")
        else
          check(val, "#{next_path}.")
        end
      end
    end
  end
end
