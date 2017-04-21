desc "Returns `GC.stat` for each Sidekiq process in JSON"
task "sidekiq:gc_stat" do
  pids = `ps -eo pid,args | grep ' [s]idekiq ' | awk '{print $1}'`.split("\n").map(&:to_i)
  results = []
  hostname = `hostname`.chomp

  pids.each do |pid|
    tmp_path = Tempfile.new.path

    system(
      "bundle exec rbtrace -p #{pid} -e \"o = GC.stat; f = File.open('#{tmp_path}', 'w'); f.write(o.to_json); f.close\"",
      out: "/dev/null", err: "/dev/null"
    )

    result = JSON.parse(File.read(tmp_path))
    result["hostname"] = hostname
    results << result
  end

  puts results.to_json
end
