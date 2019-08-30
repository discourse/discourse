# frozen_string_literal: true

require "demon/base"

class Demon::Sidekiq < Demon::Base
  RANDOM_HEX = SecureRandom.hex
  QUEUE_IDS = []

  def self.queues_last_heartbeat_hash_key
    @@queues_last_heartbeat_hash_key ||= "#{RANDOM_HEX}_queues_last_heartbeat_hash"
  end

  def self.trigger_heartbeat(name)
    $redis.hset(queues_last_heartbeat_hash_key, name, Time.new.to_i.to_s)
    extend_expiry(queues_last_heartbeat_hash_key)
  end

  def self.get_queue_last_heartbeat(name)
    extend_expiry(queues_last_heartbeat_hash_key)
    $redis.hget(queues_last_heartbeat_hash_key, name).to_i
  end

  def self.clear_heartbeat_queues!
    $redis.del(queues_last_heartbeat_hash_key)
  end

  def self.before_start(count)
    # cleans up heartbeat queues from previous boot up
    Sidekiq::Queue.all.each { |queue| queue.clear if queue.name[/^\h{32}$/] }
    count.times do
      QUEUE_IDS << SecureRandom.hex
    end
  end

  def self.extend_expiry(key)
    $redis.expire(key, 60 * 60)
  end

  def self.prefix
    "sidekiq"
  end

  def self.after_fork(&blk)
    blk ? (@blk = blk) : @blk
  end

  def run
    @identifier = QUEUE_IDS[@index]
    super
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

    [['critical', 8], [@identifier, 8], ['default', 4], ['low', 2], ['ultra_low', 1]].each do |queue_name, weight|
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
