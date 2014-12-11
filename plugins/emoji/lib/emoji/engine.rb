module Emoji
  class Engine < ::Rails::Engine
    isolate_namespace Emoji
  end

  def self.all
    return @all if defined?(@all)
    @all = parse_db
  end

  def self.db_file
    File.expand_path('../../../db.json', __FILE__)
  end

  private

    def self.parse_db
      File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }
    end
end
