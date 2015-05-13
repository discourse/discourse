desc "Migrate old polls to new syntax"
task "poll:migrate_old_polls" => :environment do
  require "timecop"
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
        post.raw = post.raw.gsub(/\n\n([ ]*[-\*\+] )/, "\n\\1") + "\n\n"
        # fix the RAW when needed
        if post.raw !~ /\[poll\]/
          lists = /^[ ]*[-\*\+] .+?$\n\n/m.match(post.raw)
          next if lists.blank? || lists.length == 0
          first_list = lists[0]
          post.raw = post.raw.sub(first_list, "\n[poll]\n#{first_list}\n[/poll]\n")
        end
        # save the poll
        post.save
        # make sure we have a poll
        next if post.custom_fields.blank? || !post.custom_fields.include?("polls")
        # retrieve the new options
        options = post.custom_fields["polls"]["poll"]["options"]
        # iterate over all votes
        PluginStoreRow.where(plugin_name: "poll")
                      .where("key LIKE 'poll_vote_#{post_id}_%'")
                      .pluck(:key, :value)
                      .each do |poll_vote_key, vote|
          # extract the user_id
          user_id = poll_vote_key["poll_vote_#{post_id}_%".length..-1].to_i
          # find the selected option
          vote = vote.strip
          selected_option = options.detect { |o| o["html"].strip === vote }
          # make sure we have a match
          next if selected_option.blank?
          # submit vote
          DiscoursePoll::Poll.vote(post_id, "poll", [selected_option["id"]], user_id) rescue nil
        end
      end
    end
  end

  puts "", "Done!"
end
