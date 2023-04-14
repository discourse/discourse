# frozen_string_literal: true

##
# In some cases we may want to enqueue_at several of the same job with
# batches, spacing them out or incrementing by some amount of seconds,
# in case the jobs do heavy work or send many MessageBus messages and the like.
# This class handles figuring out the seconds increments.
#
# @example
#   spacer = JobTimeSpacer.new
#   user_ids.in_groups_of(200, false) do |user_id_batch|
#     spacer.enqueue(:kick_users_from_topic, { topic_id: topic_id, user_ids: user_id_batch })
#   end
class JobTimeSpacer
  def initialize(seconds_space_increment: 1, seconds_delay: 5)
    @seconds_space_increment = seconds_space_increment
    @seconds_space_modifier = seconds_space_increment
    @seconds_step = seconds_delay
  end

  def enqueue(job_name, job_args = {})
    Jobs.enqueue_at((@seconds_step * @seconds_space_modifier).seconds.from_now, job_name, job_args)
    @seconds_space_modifier += @seconds_space_increment
  end
end
