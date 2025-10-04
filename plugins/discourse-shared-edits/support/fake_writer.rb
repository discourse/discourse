# frozen_string_literal: true
require "fileutils"

Dir.chdir(File.expand_path("../../../..", __FILE__)) do # rubocop:disable Discourse/NoChdir
  require File.expand_path("../../config/environment", __FILE__)

  post_id = ARGV[0].to_i

  if post_id == 0
    STDERR.puts "Please specify a post id"
    exit 1
  end

  puts "Simulating writing on #{post_id}"

  post = Post.find(post_id)

  revisions = %w[the quick brown fox jumped over the lazy fox.].map { |s| s + " " }

  revisions << { d: revisions.join.length }

  i = 0
  while true
    rev = [revisions[i % revisions.length]]
    ver = SharedEditRevision.where(post_id: post_id).maximum(:version)
    SharedEditRevision.revise!(
      post_id: post.id,
      user_id: 1,
      client_id: "a",
      revision: rev,
      version: ver,
    )
    sleep(rand * 0.2 + 0.5)
    print "."
    i += 1
  end
end
