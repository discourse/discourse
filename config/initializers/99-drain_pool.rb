# pg performs inconsistently with large amounts of connections
# this helps keep connection counts in check
Thread.new do
  while true
    sleep 30
    pools = []
    ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::ConnectionPool){|pool| pools << pool}

    pools.each do |pool|
      pool.drain(30.seconds)
    end
  end
end
