# loaded really early
module Plugin; end

class Plugin::Metadata
  FIELDS ||= [:name, :about, :version, :authors, :url, :required_version]
  attr_accessor *FIELDS

  def self.parse(text)
    metadata = self.new
    text.each_line do |line|
      break unless metadata.parse_line(line)
    end
    metadata
  end

  def parse_line(line)
    line = line.strip

    unless line.empty?
      return false unless line[0] == "#"
      attribute, *description = line[1..-1].split(":")

      description = description.join(":")
      attribute = attribute.strip.gsub(/ /, '_').to_sym

      if FIELDS.include?(attribute)
        self.send("#{attribute}=", description.strip)
      end
    end

    true
  end
end
