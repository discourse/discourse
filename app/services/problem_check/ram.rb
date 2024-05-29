# frozen_string_literal: true

class ProblemCheck::Ram < ProblemCheck
  self.priority = "low"

  def call
    available_memory = MemInfo.new

    return no_problem if available_memory.unknown?
    return no_problem if available_memory.mem_total > 950_000

    problem
  end
end
