#frozen_string_literal: true

class DiscourseAi::Evals::Runner
  class StructuredLogger
    def initialize
      @log = []
      @current_step = @log
    end

    def log(name, args: nil, start_time: nil, end_time: nil)
      start_time ||= Time.now.utc
      end_time ||= Time.now.utc
      args ||= {}
      object = { name: name, args: args, start_time: start_time, end_time: end_time }
      @current_step << object
    end

    def step(name, args: nil)
      start_time = Time.now.utc
      start_step = @current_step

      new_step = { type: :step, name: name, args: args || {}, log: [], start_time: start_time }

      @current_step << new_step
      @current_step = new_step[:log]
      yield new_step
      @current_step = start_step
      new_step[:end_time] = Time.now.utc
    end

    def to_trace_event_json
      trace_events = []
      process_id = 1
      thread_id = 1

      to_trace_event(@log, process_id, thread_id, trace_events)

      JSON.pretty_generate({ traceEvents: trace_events })
    end

    private

    def to_trace_event(log_items, pid, tid, trace_events, parent_start_time = nil)
      log_items.each do |item|
        if item.is_a?(Hash) && item[:type] == :step
          trace_events << {
            name: item[:name],
            cat: "default",
            ph: "B", # Begin event
            pid: pid,
            tid: tid,
            args: item[:args],
            ts: timestamp_in_microseconds(item[:start_time]),
          }

          to_trace_event(item[:log], pid, tid, trace_events, item[:start_time])

          trace_events << {
            name: item[:name],
            cat: "default",
            ph: "E", # End event
            pid: pid,
            tid: tid,
            ts: timestamp_in_microseconds(item[:end_time]),
          }
        else
          trace_events << {
            name: item[:name],
            cat: "default",
            ph: "B",
            pid: pid,
            tid: tid,
            args: item[:args],
            ts: timestamp_in_microseconds(item[:start_time] || parent_start_time || Time.now.utc),
            s: "p", # Scope: process
          }
          trace_events << {
            name: item[:name],
            cat: "default",
            ph: "E",
            pid: pid,
            tid: tid,
            ts: timestamp_in_microseconds(item[:end_time] || Time.now.utc),
            s: "p",
          }
        end
      end
    end

    def timestamp_in_microseconds(time)
      (time.to_f * 1_000_000).to_i
    end
  end

  attr_reader :llms, :cases

  def self.evals_paths
    @eval_paths ||= Dir.glob(File.join(File.join(__dir__, "../cases"), "*/*.yml"))
  end

  def self.evals
    @evals ||= evals_paths.map { |path| DiscourseAi::Evals::Eval.new(path: path) }
  end

  def self.print
    evals.each(&:print)
  end

  def initialize(eval_name:, llms:)
    @llms = llms
    @eval = self.class.evals.find { |c| c.id == eval_name }

    if !@eval
      puts "Error: Unknown evaluation '#{eval_name}'"
      exit 1
    end

    if @llms.empty?
      puts "Error: Unknown model 'model'"
      exit 1
    end
  end

  def run!
    puts "Running evaluation '#{@eval.id}'"

    structured_log_filename = "#{@eval.id}-#{Time.now.strftime("%Y%m%d-%H%M%S")}.json"
    log_filename = "#{@eval.id}-#{Time.now.strftime("%Y%m%d-%H%M%S")}.log"
    logs_dir = File.join(__dir__, "../log")
    FileUtils.mkdir_p(logs_dir)

    log_path = File.expand_path(File.join(logs_dir, log_filename))
    structured_log_path = File.expand_path(File.join(logs_dir, structured_log_filename))

    logger = Logger.new(File.open(log_path, "a"))
    logger.info("Starting evaluation '#{@eval.id}'")

    Thread.current[:llm_audit_log] = logger
    structured_logger = Thread.current[:llm_audit_structured_log] = StructuredLogger.new

    structured_logger.step("Evaluating #{@eval.id}", args: @eval.to_json) do
      llms.each do |llm|
        if @eval.vision && !llm.vision?
          logger.info("Skipping LLM: #{llm.name} as it does not support vision")
          next
        end

        structured_logger.step("Evaluating with LLM: #{llm.name}") do |step|
          logger.info("Evaluating with LLM: #{llm.name}")
          print "#{llm.name}: "
          results = @eval.run(llm: llm)

          results.each do |result|
            step[:args] = result
            step[:cname] = result[:result] == :pass ? :good : :bad

            if result[:result] == :fail
              puts "Failed 🔴"
              puts "Error: #{result[:message]}" if result[:message]
              # this is deliberate, it creates a lot of noise, but sometimes for debugging it's useful
              #puts "Context: #{result[:context].to_s[0..2000]}" if result[:context]
              if result[:expected_output] && result[:actual_output]
                puts "---- Expected ----\n#{result[:expected_output]}"
                puts "---- Actual ----\n#{result[:actual_output]}"
              end
              logger.error("Evaluation failed with LLM: #{llm.name}")
              logger.error("Error: #{result[:message]}") if result[:message]
              logger.error("Expected: #{result[:expected_output]}") if result[:expected_output]
              logger.error("Actual: #{result[:actual_output]}") if result[:actual_output]
              logger.error("Context: #{result[:context]}") if result[:context]
            elsif result[:result] == :pass
              puts "Passed 🟢"
              logger.info("Evaluation passed with LLM: #{llm.name}")
            else
              STDERR.puts "Error: Unknown result #{eval.inspect}"
              logger.error("Unknown result: #{eval.inspect}")
            end
          end
        end
      end
    end

    #structured_logger.save(structured_log_path)

    File.write("#{structured_log_path}", structured_logger.to_trace_event_json)

    puts
    puts "Log file: #{log_path}"
    puts "Structured log file (ui.perfetto.dev): #{structured_log_path}"

    # temp code
    # puts File.read(structured_log_path)
  end
end
