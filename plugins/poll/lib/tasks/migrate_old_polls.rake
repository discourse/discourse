desc "Migrate old polls to new syntax"
task "poll:migrate_old_polls" => :environment do
  # iterate over all polls
  PluginStoreRow.where(plugin_name: "poll")
                .where("key LIKE 'poll_options_%'")
                .pluck(:key)
                .each do |poll_options_key|
    # extract the post_id
    post_id = poll_options_key["poll_options_".length..-1].to_i
    # load the post from the db
    if post = Post.find_by(id: post_id)
      putc "."
      # go back in time
      Timecop.freeze(post.created_at + 1.minute) do
        # fix the RAW when needed
        if post.raw !~ /\[poll\]/
          first_list = /(^- .+?$\n)\n/m.match(post.raw)[0]
          post.raw = post.raw.sub(first_list, "[poll]\n#{first_list}\n[/poll]")
        else
          post.raw = post.raw + " "
        end
        # save the poll
        post.save
        # iterate over all votes
        PluginStoreRow.where(plugin_name: "poll")
                      .where("key LIKE 'poll_vote_#{post_id}_%'")
                      .pluck(:key, :value)
                      .each do |poll_vote_key, vote|
          # extract the user_id
          user_id = poll_vote_key["poll_vote_#{post_id}_%".length..-1].to_i
          # conver to MD5 (use the same algorithm as the client-side poll dialect)
          options = [Digest::MD5.hexdigest([vote].to_json)]
          # submit vote
          DiscoursePoll::Poll.vote(post_id, "poll", options, user_id) rescue nil
        end
      end
    end
  end

  puts "", "Done!"
end
