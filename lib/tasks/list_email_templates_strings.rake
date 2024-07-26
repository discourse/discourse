# frozen_string_literal: true

def check(obj, path, result)
  obj.each do |key, val|
    if Hash === val
      next_path = "#{path}#{key}"
      if val.key?("text_body_template") && val.key?("subject_template")
        result << next_path.sub("en.", "")
      else
        check(val, "#{next_path}.", result)
      end
    end
  end
end

task "list_email_templates_strings" => :environment do
  path = File.join(Rails.root, "config", "locales", "server.en.yml")
  yaml = YAML.load_file(path, aliases: true)
  result = []
  check(yaml, "", result)
  puts result.sort
end
