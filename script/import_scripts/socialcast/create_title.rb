# frozen_string_literal: true

require 'uri'

class CreateTitle

  def self.from_body(body)
    title = remove_mentions body
    title = remove_urls title
    title = remove_stray_punctuation title
    title = first_long_line title
    return unless title

    sentences = complete_sentences title
    if !sentences.nil?
      title = sentences[1]
    else
      title = complete_words title
    end

    return title unless title.nil? || title.size < 20
  end

  private

  def self.remove_mentions(text)
    text.gsub(/@[\w]*/, '')
  end

  def self.remove_urls(text)
    text.gsub(URI::regexp(['http', 'https', 'mailto', 'ftp', 'ldap', 'ldaps']), '')
  end

  def self.remove_stray_punctuation(text)
    text.gsub(/\s+?[^a-zA-Z0-9\s]\s+/, "\n")
  end

  def self.first_long_line(text)
    lines = text.split("\n").select { |t| t.strip.size >= 20 }
    return if lines.empty?
    lines[0].strip
  end

  def self.complete_sentences(text)
    /(^.*[\S]{2,}[.!?:]+)\W/.match(text[0...80] + ' ')
  end

  def self.complete_words(text)
    return text[0...80].rpartition(/\s/)[0] + "..." if text.size >= 80
    text
  end
end
