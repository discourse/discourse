# frozen_string_literal: true

def list_files(base_dir, pattern = "*")
  Dir[File.join("#{base_dir}", pattern)]
end

def grep_files(files, regex)
  files.select { |file| grep_file(file, regex) }
end

def grep_file(file, regex)
  lines = File.open(file).grep(regex)
  lines.count > 0 ? file : nil
end

RSpec.describe "Coding style" do
  describe "Post Migrations" do
    def check_offenses(files, method_name, constant_name)
      method_name_regex = /#{Regexp.escape(method_name)}/
      constant_name_regex = /#{Regexp.escape(constant_name)}/
      offenses = files.reject { |file| is_valid?(file, method_name_regex, constant_name_regex) }

      expect(offenses).to be_empty, <<~TEXT
        You need to use the constant #{constant_name} when you use
        #{method_name} in order to help with restoring backups.

        Please take a look at existing migrations to see how to use it correctly.

        Offenses:
        #{offenses.join("\n")}
      TEXT
    end

    def is_valid?(file, method_name_regex, constant_name_regex)
      contains_method_name = File.open(file).grep(method_name_regex).any?
      contains_constant_name = File.open(file).grep(constant_name_regex).any?

      contains_method_name ? contains_constant_name : true
    end

    it "ensures dropped tables and columns are stored in constants" do
      migration_files = list_files("db/post_migrate", "**/*.rb")

      check_offenses(migration_files, "ColumnDropper.execute_drop", "DROPPED_COLUMNS")
      check_offenses(migration_files, "TableDropper.execute_drop", "DROPPED_TABLES")
    end
  end

  describe "non-colocated component templates" do
    {
      "discourse" => "app/assets/javascripts/discourse/app/templates/components",
      "admin" => "app/assets/javascripts/admin/addon/templates/components",
      "wizard" => "app/assets/javascripts/wizard/addon/templates/components",
      "chat/discourse" => "plugins/chat/assets/javascripts/discourse/templates/components",
      "chat/admin" => "plugins/chat/assets/javascripts/admin/templates/components",
      "styleguide" => "plugins/styleguide/assets/javascripts/discourse/templates/components",
    }.each_pair do |name, dir|
      it "do not exist for #{name}" do
        expect(list_files(dir)).to eq([])
      end
    end
  end
end
