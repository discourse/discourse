# frozen_string_literal: true

describe DiscourseAi::Completions::CancelManager do
  fab!(:model) { Fabricate(:anthropic_model, name: "test-model") }

  before do
    enable_current_plugin
    WebMock.allow_net_connect!
  end

  it "can stop monitoring for cancellation cleanly" do
    cancel_manager = DiscourseAi::Completions::CancelManager.new
    cancel_manager.start_monitor(delay: 100) { false }
    expect(cancel_manager.monitor_thread).not_to be_nil
    cancel_manager.stop_monitor
    expect(cancel_manager.cancelled?).to eq(false)
    expect(cancel_manager.monitor_thread).to be_nil
  end

  it "can monitor for cancellation" do
    cancel_manager = DiscourseAi::Completions::CancelManager.new
    results = [true, false, false]

    cancel_manager.start_monitor(delay: 0) { results.pop }

    wait_for { cancel_manager.cancelled? == true }
    wait_for { cancel_manager.monitor_thread.nil? }

    expect(cancel_manager.cancelled?).to eq(true)
    expect(cancel_manager.monitor_thread).to be_nil
  end

  it "should do nothing when cancel manager is already cancelled" do
    cancel_manager = DiscourseAi::Completions::CancelManager.new
    cancel_manager.cancel!

    llm = model.to_llm
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are a test bot",
        messages: [{ type: :user, content: "hello" }],
      )

    result = llm.generate(prompt, user: Discourse.system_user, cancel_manager: cancel_manager)
    expect(result).to be_nil
  end

  it "should be able to cancel a completion" do
    # Start an HTTP server that hangs indefinitely
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    begin
      thread =
        Thread.new do
          loop do
            begin
              _client = server.accept
              sleep(30) # Hold the connection longer than the test will run
              break
            rescue StandardError
              # Server closed
              break
            end
          end
        end

      # Create a model that points to our hanging server
      model.update!(url: "http://127.0.0.1:#{port}")

      cancel_manager = DiscourseAi::Completions::CancelManager.new

      completion_thread =
        Thread.new do
          llm = model.to_llm
          prompt =
            DiscourseAi::Completions::Prompt.new(
              "You are a test bot",
              messages: [{ type: :user, content: "hello" }],
            )

          result = llm.generate(prompt, user: Discourse.system_user, cancel_manager: cancel_manager)
          expect(result).to be_nil
          expect(cancel_manager.cancelled).to eq(true)
        end

      wait_for { cancel_manager.callbacks.size == 1 }

      cancel_manager.cancel!

      # on slow machines this may take a bit longer to cancel, usually on a fast machine this is instant
      completion_thread.join(5)

      begin
        expect(completion_thread).not_to be_alive
      rescue RSpec::Expectations::ExpectationNotMetError
        puts "Thread still alive - dumping backtraces:"
        Thread.list.each do |t|
          puts "Thread #{t.object_id}: #{t.status}"
          puts t.backtrace&.join("\n")
          puts
        end
        raise
      end
    ensure
      begin
        server.close
      rescue StandardError
        nil
      end
      begin
        thread.kill
      rescue StandardError
        nil
      end
      begin
        completion_thread&.kill
      rescue StandardError
        nil
      end
    end
  end
end
