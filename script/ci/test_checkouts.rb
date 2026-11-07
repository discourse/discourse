# frozen_string_literal: true
require "json"

unless ARGV.length == 2 && %w[plugins themes].include?(ARGV[1])
  raise ArgumentError, "Expected CATALOG plugins|themes"
end
catalog = JSON.parse(File.read(ARGV[0]))
catalog
  .fetch("checkouts")
  .each do |path, revision|
    unless path.match?(%r{\A(?:plugins|tmp/themes)/[A-Za-z0-9_-]+\z}) &&
             revision.match?(/\A[0-9a-f]{40}\z/)
      raise ArgumentError, "Invalid external checkout identity"
    end
    next unless path.start_with?(ARGV[1] == "plugins" ? "plugins/" : "tmp/themes/")
    raise ArgumentError, "Missing external checkout: #{path}" unless File.directory?("#{path}/.git")
    system(
      "git",
      "-C",
      path,
      "fetch",
      "--no-tags",
      "--depth=1",
      "origin",
      revision,
      exception: true,
    )
    system("git", "-C", path, "checkout", "--detach", revision, exception: true)
  end
