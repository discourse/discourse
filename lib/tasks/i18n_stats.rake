require 'yaml'

desc "show the current translation status"
task "i18n:stats" => :environment do

  def to_dotted_hash(source, target = {}, namespace = nil)
    prefix = "#{namespace}." if namespace
    if source.kind_of?(Hash)
      source.each do |key, value|
        to_dotted_hash(value, target, "#{prefix}#{key}")
      end
    else
      target[namespace] = source
    end
    target
  end

  def compare(a, b)
    locale1 = /.*\.([^.]{2,})\.yml$/.match(a)[1]
    locale2 = /.*\.([^.]{2,})\.yml$/.match(b)[1]

    a = YAML.load_file("#{Rails.root}/config/locales/#{a}")[locale1]
    b = YAML.load_file("#{Rails.root}/config/locales/#{b}")[locale2]
    a = to_dotted_hash(a)
    b = to_dotted_hash(b)

    plus = []
    minus = []
    same = []
    total = a.count

    a.each do |key,value|
      if b[key] == nil
        minus << key
      end
      if a[key] == b[key]
        same << key
      end
    end

    b.each do |key,value|
      if a[key] == nil
        plus << key
      end
    end

    return plus,minus,same,total
  end

  puts "Discourse Translation Status Script"
  puts "To show details about a specific locale (e.g. 'de'), run as:"
  puts "    rake i18n:stats locale=de"
  puts ""

  filemask = "client.*.yml"
  details = false
  if ENV['locale'] != nil
    filemask = "client.#{ENV['locale']}.yml"
    details = true
  end

  puts "   locale |  cli+  |  cli-  |  cli=  | cli tot|  srv+  |  srv-  |  srv=  | srv tot"
  puts "----------------------------------------------------------------------------------"

  Dir["#{Rails.root}/config/locales/#{filemask}"].each do |f|
    locale = /.*\.([^.]{2,})\.yml$/.match(f)[1]
    next if locale == "en"
    next if !File.exists?("#{Rails.root}/config/locales/client.#{locale}.yml")
    next if !File.exists?("#{Rails.root}/config/locales/server.#{locale}.yml")

    plus1, minus1, same1, total1 = compare("client.en.yml", "client.#{locale}.yml")
    plus2, minus2, same2, total2 = compare("server.en.yml", "server.#{locale}.yml")
    puts "%10s %8s %8s %8s %8s %8s %8s %8s %8s" % [locale, plus1.count, minus1.count, same1.count, total1,
                                                   plus2.count, minus2.count, same2.count, total2]

    if details
      puts ""
      puts "Equal keys:"
      same1.each { |k| puts "client: #{locale}.#{k}" }
      same2.each { |k| puts "server: #{locale}.#{k}" }
      puts ""
      puts "Missing keys:"
      minus1.each { |k| puts "client: #{locale}.#{k}" }
      minus2.each { |k| puts "server: #{locale}.#{k}" }
      puts ""
      puts "Surplus keys:"
      plus1.each { |k| puts "client: #{locale}.#{k}" }
      plus2.each { |k| puts "server: #{locale}.#{k}" }
    end
  end

end
