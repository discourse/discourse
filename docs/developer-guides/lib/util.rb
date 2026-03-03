# frozen_string_literal: true

module Util
  def self.parse_md(raw)
    if match = raw.match(/\A---\s*\n(.+?)\n---\n?(.*)\z/m)
      raw_frontmatter, content = match.captures
      frontmatter = YAML.safe_load(raw_frontmatter)
    else
      content = raw
      frontmatter = {}
    end

    [frontmatter, content]
  end
end
