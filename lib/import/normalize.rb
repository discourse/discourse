# markdown normalizer to be used by importers
#
#
require 'htmlentities'
module Import; end
module Import::Normalize
  def self.normalize_code_blocks(code, lang = nil)
    coder = HTMLEntities.new
    code.gsub(/<pre>\s*<code>\n?(.*?)\n?<\/code>\s*<\/pre>/m) {
      "\n```#{lang}\n#{coder.decode($1)}\n```\n"
    }
  end
end
