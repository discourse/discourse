require 'socket_server'

class StatsSocket < SocketServer

  def initialize(socket_path)
    super(socket_path)
  end

  protected

  def get_response(command)
    result =
      case command
      when "gc_stat"
        GC.stat.to_json
      when "v8_stat"
        stats = {}
        ObjectSpace.each_object(MiniRacer::Context) do |context|
          context.heap_stats.each do |k, v|
            stats[k] = (stats[k] || 0) + v
          end
        end
        stats.to_json
      else
        "[\"UNKNOWN COMMAND\"]"
      end

    result << "\n"
  end

end
