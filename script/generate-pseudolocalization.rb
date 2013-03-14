#!/usr/bin/env ruby
# -*- encoding : utf-8 -*-

require 'yaml'

def pseudolocalize(str)
  n = 0
  newstr = ""
  str.each_char { |c|
    if c == "{"
      n += 1
    elsif c == "}"
      n -= 1
    end

    if n < 1
      newstr += c.tr("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", 
                     "áƀčďéƒǧĥíʲǩłɱɳóƿƣřšťůνŵхýžÁƁČĎÉƑǦĤÍǰǨŁϺЍÓРƢŘŠŤŮѶŴХÝŽ")
    else
      newstr += c
    end
  }
  return "[[ #{newstr} ]]"
end

def transform(p)
  if p.kind_of?(Hash)
    newhash = Hash.new
    p.each { |key, value| newhash[key] = transform(value) }
    return newhash
  elsif p.kind_of?(String)
    return pseudolocalize(p)
  else
    raise "Oops, unknown thing in the YML"
  end
end

def replace(hash, hash2, dotted_path)
  parts = dotted_path.split '.', 2
  match = hash[parts[0]]
  if !parts[1] or match.nil?
    return match
  else
    return dig(match, parts[1])
  end
end

def process_file(basename, locale, &block)
  strings = YAML.load_file("./config/locales/#{basename}.#{locale}.yml")
  new_strings = transform(strings)
  new_strings = Hash["pseudo" => new_strings[locale]]
  yield new_strings, strings if block_given?
  File.open("./config/locales/#{basename}.pseudo.yml", 'w+' ) do |f|
    f.puts new_strings.to_yaml
  end
end

process_file("client", "en")
process_file("server", "en") { |new,orig| new["pseudo"]["time"] = orig["en"]["time"] }
