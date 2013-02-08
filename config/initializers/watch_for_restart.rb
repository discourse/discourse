Thread.new do 
  file = "#{Rails.root}/tmp/restart"
  did_exist = nil
  old_time = nil

  return if $PROGRAM_NAME !~ /thin/
  
  processes = {}
  got_new = false
  MessageBus.subscribe "/processes" do |msg|
    filetime = msg.data["filetime"]
    pid = msg.data["pid"]
    got_new = processes[pid].nil? || (processes[pid][:filetime] != filetime)
    # puts "#{got_new} #{pid}"
    processes[pid] = {time: Time.now.to_i, filetime: filetime} 
  end
  
  while true
    exists = File.exists? file 
    time = File.ctime(file).to_i if exists
    
    if (did_exist != nil && did_exist != exists) ||
      (old_time != nil && time != nil && old_time != time)

      got_new = false
      probably_restarted = []

      give_up_time = Time.now.to_i + 60

      while Time.now.to_i < give_up_time
        candidates = []
        processes.each do |pid,data|
          if data[:filetime] == old_time && data[:time] > Time.now.to_i - 40
            candidates << pid
          end
        end

        candidates = candidates - probably_restarted

        break if (candidates.min || $$) >= $$ 
        sleep 1
        probably_restarted << candidates.min if got_new
        got_new = false
      end
      

      Rails.logger.info "attempting to reload #{$$} #{$PROGRAM_NAME} in 3 seconds restarted #{probably_restarted.inspect}"
      $shutdown = true
      sleep 4
      Rails.logger.info "restarting #{$$}" 
      Process.kill("HUP", $$) 
      
      break
    end

    MessageBus.publish "/processes", {pid: $$, filetime: time}
    did_exist = exists
    old_time = time
    sleep 1
  end
end
