# frozen_string_literal: true

# this is a trivial graceful restart on touch of tmp/restart.
#
# It simply drains all the requests (waits up to 4 seconds) and issues a HUP
#  if you need a more sophisticated cycling restart for multiple thins it will need to be written
#
# This works fine for Discourse.org cause we host our app accross multiple machines, if you hosting
#  on a single machine you have a trickier problem at hand as you need to cycle the processes in order
#

# VIM users rejoice, if you add this to your .vimrc CTRL-a will restart puma:
# nmap <C-a> <Esc>:!touch tmp/restart<CR><CR>

Thread.new do
  file = "#{Rails.root}/tmp/restart"
  old_time = File.ctime(file).to_i if File.exists? file
  wait_seconds = 4

  if Rails.env.development? && $PROGRAM_NAME =~ /puma/
    require 'listen'

    time = nil

    begin
      listener = Listen.to("#{Rails.root}/tmp", only: /restart/) do

        time = File.ctime(file).to_i if File.exists? file

        if old_time != time
          Rails.logger.info "attempting to reload #{$$} #{$PROGRAM_NAME} in #{wait_seconds} seconds"
          $shutdown = true # rubocop:disable Style/GlobalVars
          sleep wait_seconds
          Rails.logger.info "restarting #{$$}"
          Process.kill("USR2", $$)
        end
      end
      listener.start
      sleep
    rescue => e
      puts "Failed to watch for restart, this probably means the old postgres directory is in tmp, remove it #{e}"
    end
  end
end
