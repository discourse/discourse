# frozen_string_literal: true

# TODO: Remove this after the Discourse 3.5 release
class SidekiqMigration
  delegate :old_pool, to: :Sidekiq

  def self.call
    new.call
  end

  def call
    migrate_all_queues
    migrate(klass: Sidekiq::RetrySet)
    migrate(klass: Sidekiq::ScheduledSet)
  end

  private

  def migrate_all_queues
    migrate(
      old_jobs: -> { Sidekiq::Queue.all.flat_map(&:to_a) },
      enqueue_jobs: ->(job) { client.push(job.item) },
    )
  end

  def migrate(
    klass: nil,
    old_jobs: -> { klass.new.to_a },
    enqueue_jobs: ->(job) { klass.new.schedule(job.score, job.item) }
  )
    jobs_to_migrate = Sidekiq::Client.via(old_pool, &old_jobs)
    jobs_to_migrate.each(&enqueue_jobs)
    Sidekiq::Client.via(old_pool) { jobs_to_migrate.each(&:delete) }
  end

  def client
    @client ||= Sidekiq::Client.new
  end
end
