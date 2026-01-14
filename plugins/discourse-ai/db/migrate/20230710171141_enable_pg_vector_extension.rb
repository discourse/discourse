# frozen_string_literal: true

class EnablePgVectorExtension < ActiveRecord::Migration[7.0]
  def change
    unless extension_enabled?(:vector)
      begin
        enable_extension :vector
      rescue StandardError => e
        if DB.query_single("SELECT 1 FROM pg_available_extensions WHERE name = 'vector';").empty?
          STDERR.puts "------------------------------DISCOURSE AI ERROR----------------------------------"
          STDERR.puts "    Discourse AI requires the pgvector extension on the PostgreSQL database."
          STDERR.puts "         Run a `./launcher rebuild app` to fix it on a standard install."
          STDERR.puts "            Alternatively, you can remove Discourse AI to rebuild."
          STDERR.puts "------------------------------DISCOURSE AI ERROR----------------------------------"
        end
        raise e
      end
    end
  end
end
