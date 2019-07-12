# frozen_string_literal: true

require "demon/base"

class Demon::Sidekiq < Demon::Base
  RANDOM_HEX = SecureRandom.hex

  def self.heartbeat_queues_list_key
    @@heartbeat_queues_list_key ||= "#{RANDOM_HEX}_heartbeat_queues_list"
  end

  def self.queues_last_heartbeat_hash_key
    @@queues_last_heartbeat_hash_key ||= "#{RANDOM_HEX}_queues_last_heartbeat_hash"
  end

  def self.trigger_heartbeat(name)
    $redis.hset(queues_last_heartbeat_hash_key, name, Time.new.to_i.to_s)
  end

  def self.get_queue_last_heartbeat(name)
    $redis.hget(queues_last_heartbeat_hash_key, name)&.to_i || 0
  end

  def self.heartbeat_queues
    queues = $redis.lrange(heartbeat_queues_list_key, 0, -1)

    queues.select! do |queue|
      pid = queue.split("_").last.to_i
      alive = alive?(pid)
      if !alive
        $redis.lrem(heartbeat_queues_list_key, 0, queue)
        $redis.hdel(queues_last_heartbeat_hash_key, queue)
      end
      alive
    end
    queues
  end

  def self.create_heartbeat_queue(pid)
    queue = "#{SecureRandom.hex}_#{pid}"
    $redis.lpush(heartbeat_queues_list_key, queue)
    queue
  end

  def self.clear_heartbeat_queues!
    $redis.del(heartbeat_queues_list_key)
    $redis.del(queues_last_heartbeat_hash_key)
  end

  def self.before_start
    # cleans up heartbeat queues from previous boot up
    Sidekiq::Queue.all.each do |queue|
      next if queue.name !~ /^[a-f0-9]{32}_\d+$/
      queue.clear if queue.size == 0
    end
  end

  def self.prefix
    "sidekiq"
  end

  def self.after_fork(&blk)
    blk ? (@blk = blk) : @blk
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def after_fork
    Demon::Sidekiq.after_fork&.call

    puts "Loading Sidekiq in process id #{Process.pid}"
    require 'sidekiq/cli'
    # CLI will close the logger, if we have one set we can be in big
    # trouble, if STDOUT is closed in our process all sort of weird
    # will ensue, resetting the logger ensures it will reinit correctly
    # parent process is in charge of the file anyway.
    Sidekiq::Logging.logger = nil
    cli = Sidekiq::CLI.instance

    options = ["-c", GlobalSetting.sidekiq_workers.to_s]

    heartbeat_queue = self.class.create_heartbeat_queue(Process.pid)

    [['critical', 8], [heartbeat_queue, 8], ['default', 4], ['low', 2], ['ultra_low', 1]].each do |queue_name, weight|
      custom_queue_hostname = ENV["UNICORN_SIDEKIQ_#{queue_name.upcase}_QUEUE_HOSTNAME"]

      if !custom_queue_hostname || custom_queue_hostname.split(',').include?(`hostname`.strip)
        options << "-q"
        options << "#{queue_name},#{weight}"
      end
    end

    # Sidekiq not as high priority as web, in this environment it is forked so a web is very
    # likely running
    Discourse::Utils.execute_command('renice', '-n', '5', '-p', Process.pid.to_s)

    cli.parse(options)
    load Rails.root + "config/initializers/100-sidekiq.rb"
    cli.run
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end

end
