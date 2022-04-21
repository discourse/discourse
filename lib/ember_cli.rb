# frozen_string_literal: true

module EmberCli
  ALIASES ||= {
    "application" => "discourse",
    "discourse/tests/test-support-rails" => "test-support",
    "discourse/tests/test-helpers-rails" => "test-helpers"
  }

  def self.enabled?
    ENV["EMBER_CLI_PROD_ASSETS"] != "0"
  end

  def self.script_chunks
    return @@chunk_infos if defined? @@chunk_infos

    raw_chunk_infos = JSON.parse(File.read("#{Rails.configuration.root}/app/assets/javascripts/discourse/dist/chunks.json"))

    chunk_infos = raw_chunk_infos["scripts"].map do |info|
      logical_name = info["afterFile"][/\Aassets\/(.*)\.js\z/, 1]
      chunks = info["scriptChunks"].map { |filename| filename[/\Aassets\/(.*)\.js\z/, 1] }
      [logical_name, chunks]
    end.to_h

    @@chunk_infos = chunk_infos if Rails.env.production?
    chunk_infos
  rescue Errno::ENOENT
    {}
  end

  # Some assets have changed name following the switch
  # to ember-cli. When the switch is complete, we can
  # drop this method and update all the references
  # to use the new names
  def self.transform_name(name)
    return name if !enabled?
    ALIASES[name] || name
  end
end
