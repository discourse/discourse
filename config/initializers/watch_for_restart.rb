# this is a trivial graceful restart on touch of tmp/restart.
#
# It simply drains all the requests (waits up to 4 seconds) and issues a HUP
#  if you need a more sophisticated cycling restart for multiple thins it will need to be written
#
# This works fine for Discourse.org cause we host our app accross multiple machines, if you hosting
#  on a single machine you have a trickier problem at hand as you need to cycle the processes in order

Thread.new do
  file = "#{Rails.root}/tmp/restart"
  old_time = File.ctime(file).to_i if File.exists? file
  wait_seconds = 4

  if $PROGRAM_NAME =~ /thin/
    while true
      time = File.ctime(file).to_i if File.exists? file

      if old_time != time
        Rails.logger.info "attempting to reload #{$$} #{$PROGRAM_NAME} in #{wait_seconds} seconds"
        $shutdown = true
        sleep wait_seconds
        Rails.logger.info "restarting #{$$}"
        Process.kill("HUP", $$)
        break
      end

      sleep 1
    end
  end
end
