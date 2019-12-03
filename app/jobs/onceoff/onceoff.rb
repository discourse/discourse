# frozen_string_literal: true

require_relative '../base.rb'

class Jobs::Onceoff < ::Jobs::Base
  sidekiq_options retry: false

  def self.name_for(klass)
    klass.name.sub(/^Jobs\:\:/, '')
  end

  def running_key_name
    "#{self.class.name}:running"
  end

  # Pass `force: true` to force it happen again
  def execute(args)
    job_name = self.class.name_for(self.class)
    has_lock = Discourse.redis.setnx(running_key_name, Time.now.to_i)

    # If we can't get a lock, just noop
    if args[:force] || has_lock
      begin
        return if OnceoffLog.where(job_name: job_name).exists? && !args[:force]
        execute_onceoff(args)
        OnceoffLog.create!(job_name: job_name)
      ensure
        Discourse.redis.del(running_key_name) if has_lock
      end
    end

  end

  def self.enqueue_all
    previously_ran = OnceoffLog.pluck(:job_name).uniq

    ObjectSpace.each_object(Class).select { |klass| klass < self }.each do |klass|
      job_name = name_for(klass)
      unless previously_ran.include?(job_name)
        Jobs.enqueue(job_name.underscore.to_sym)
      end
    end
  end

end
