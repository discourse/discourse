# frozen_string_literal: true

module SidekiqHelpers
  # Assert job is enqueued:
  #
  # expect_enqueued_with(job: :post_process, args: { post_id: post.id }) do
  #   post.update!(raw: 'new raw')
  # end
  #
  # Asserting jobs enqueued with delay:
  #
  # expect_enqueued_with(
  #   job: :post_process,
  #   args: { post_id: post.id },
  #   at: Time.zone.now + 1.hour
  # ) do
  #   post.update!(raw: 'new raw')
  # end
  def expect_enqueued_with(job:, args: {}, at: nil, expectation: true)
    klass = job.instance_of?(Class) ? job : "::Jobs::#{job.to_s.camelcase}".constantize
    at = at.to_f if at.is_a?(Time)
    expected = { job: job, args: args, at: at }.compact
    original_jobs = klass.jobs.dup

    yield if block_given?

    matched_job = false
    jobs = klass.jobs - original_jobs
    matched_job = match_jobs(jobs: jobs, args: args, at: at) if jobs.present?

    expect(matched_job).to(
      eq(expectation),
      expectation ? "No enqueued job with #{expected} found" : "Enqueued job with #{expected} found"
    )
  end

  # Assert job is not enqueued:
  #
  # expect_not_enqueued_with(job: :post_process) do
  #   post.update!(raw: 'new raw')
  # end
  #
  # Assert job is not enqueued with specific params
  #
  # expect_not_enqueued_with(job: :post_process, args: { post_id: post.id }) do
  #   post.update!(raw: 'new raw')
  # end
  def expect_not_enqueued_with(job:, args: {}, at: nil)
    expect_enqueued_with(job: job, args: args, at: at, expectation: false) do
      yield
    end
  end

  # Checks whether a job has been enqueued with the given arguments
  #
  # job_enqueued?(job: :post_process, args: { post_id: post.id }) => true/false
  # job_enqueued?(job: :post_process, args: { post_id: post.id }, at: Time.zone.now + 1.hour) => true/false
  def job_enqueued?(job:, args: {}, at: nil)
    klass = job.instance_of?(Class) ? job : "::Jobs::#{job.to_s.camelcase}".constantize
    at = at.to_f if at.is_a?(Time)
    match_jobs(jobs: klass.jobs, args: args, at: at)
  end

  private

  def match_jobs(jobs:, args:, at:)
    matched_job = false

    args = JSON.parse(args.to_json)
    args.merge!(at: at) if at

    jobs.each do |job|
      job_args = job["args"].first.with_indifferent_access
      job_args.merge!(at: job["at"]) if job["at"]
      job_args.merge!(enqueued_at: job["enqueued_at"]) if job["enqueued_at"]

      matched_job ||= args.all? do |key, value|
        value = value.to_s if value.is_a?(Symbol)

        if key == :at && !job_args.has_key?(:at)
          value == job_args[:enqueued_at]
        else
          value == job_args[key]
        end
      end
    end

    matched_job
  end
end
