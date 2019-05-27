def list_files(base_dir, pattern = '*')
  Dir[File.join("#{base_dir}", pattern)]
end

def list_js_files(base_dir)
  list_files(base_dir, '**/*.es6')
end

def grep_files(files, regex)
  files.select { |file| grep_file(file, regex) }
end

def grep_file(file, regex)
  lines = File.open(file).grep(regex)
  lines.count > 0 ? file : nil
end

describe 'Coding style' do
  describe 'Javascript' do
    it 'prevents this.get("foo") pattern' do
      js_files = list_js_files('app/assets/javascripts')
      offenses = grep_files(js_files, /this\.get\("\w+"\)/)

      expect(offenses).to be_empty, <<~MSG
        Do not use this.get("foo") accessor for single property, instead
        prefer to use this.foo

        Offenses:
        #{offenses.join("\n")}
      MSG
    end
  end
end
