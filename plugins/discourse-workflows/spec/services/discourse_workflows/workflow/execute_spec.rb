# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Execute do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    end

    let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1" } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflows are not enabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:can_execute) }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1, trigger_node_id: "trigger-1" } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when trigger node does not exist" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: "nonexistent" } }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when workflow_id is not provided" do
      let(:params) { { trigger_node_id: "trigger-1" } }

      before do
        DiscourseWorkflows::WorkflowDependencyIndexer.call(
          workflow,
          version: workflow.active_version,
        )
      end

      it { is_expected.to run_successfully }

      it "finds the workflow via dependency index" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end
    end

    context "when a matched workflow version is provided" do
      let!(:matched_version) { workflow.active_version }
      let(:params) do
        {
          workflow_id: workflow.id,
          workflow_version_id: matched_version.version_id,
          trigger_node_id: "trigger-1",
        }
      end

      before do
        update_workflow_node(workflow, "trigger-1") { |node| node["id"] = "trigger-2" }
        publish_workflow!(workflow)
      end

      it { is_expected.to run_successfully }

      it "executes the matched version instead of the current active version" do
        expect(result[:workflow_version]).to eq(matched_version)
        workflow_data = result[:execution].execution_data.workflow_data
        expect(workflow_data["nodes"]).to contain_exactly(include("id" => "trigger-1"))
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates an execution record" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end
    end

    context "when no job_id is provided" do
      it "creates separate executions for repeated calls without a job ID" do
        first_execution = result[:execution]
        repeated_result = described_class.call(params:)

        expect([result, repeated_result]).to all(run_successfully)
        expect(workflow.executions).to contain_exactly(first_execution, repeated_result[:execution])
        expect(workflow.executions).to all(be_success)
      end
    end

    context "when job_id is provided" do
      let(:params) { super().merge(job_id: "workflow-service-job") }
      let(:effect_url) { "https://example.com/workflow-service-effect" }
      let(:http_response) do
        {
          status: Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:ok),
          body: "{}",
          headers: {
            "content-type" => "application/json",
          },
        }
      end

      before do
        graph =
          build_workflow_graph do |workflow_graph|
            workflow_graph.node "trigger-1", "trigger:manual"
            workflow_graph.node "effect-1",
                                "action:http_request",
                                configuration: {
                                  "method" => "POST",
                                  "url" => effect_url,
                                }
            workflow_graph.chain "trigger-1", "effect-1"
          end
        workflow.update!(**graph)
        publish_workflow!(workflow)
        stub_request(:post, effect_url).to_return(http_response)
      end

      it "returns a running execution when the same job is delivered during its HTTP request" do
        repeated_result = nil
        repeated_status = nil
        repeated_delivery_started = false
        stub_request(:post, effect_url).to_return do
          unless repeated_delivery_started
            repeated_delivery_started = true
            repeated_result = described_class.call(params:)
            repeated_status = repeated_result[:execution].status
          end

          http_response
        end

        expect(result).to run_successfully

        expect(repeated_result).to run_successfully
        expect(repeated_result[:execution].id).to eq(result[:execution].id)
        expect(repeated_status).to eq("running")
        expect(result[:execution]).to be_success
        expect(a_request(:post, effect_url)).to have_been_made.once
      end

      it "preserves the original Redis failure when unlocking a duplicate delivery" do
        first_execution = result[:execution]
        checkpoint = first_execution.execution_data.attributes.deep_dup
        unlock_error = Redis::CannotConnectError.new
        DiscourseWorkflows::Execution
          .stubs(:find_by)
          .with(job_id: params[:job_id])
          .returns(nil, first_execution)
        allow(DistributedMutex::UNLOCK_SCRIPT).to receive(
          :eval,
        ).and_wrap_original do |original, *arguments|
          original.call(*arguments)
          raise unlock_error
        end

        repeated_result = described_class.call(params:)

        expect(repeated_result).to fail_to_find_a_model(:execution)
        expect(repeated_result["result.model.execution"].exception).to equal(unlock_error)
        expect(first_execution.reload).to be_success
        expect(first_execution.execution_data.reload.attributes).to eq(checkpoint)
      end

      it "propagates shutdown when unlocking a duplicate delivery" do
        first_execution = result[:execution]
        checkpoint = first_execution.execution_data.attributes.deep_dup
        shutdown = Sidekiq::Shutdown.new
        DiscourseWorkflows::Execution
          .stubs(:find_by)
          .with(job_id: params[:job_id])
          .returns(nil, first_execution)
        allow(DistributedMutex::UNLOCK_SCRIPT).to receive(
          :eval,
        ).and_wrap_original do |original, *arguments|
          original.call(*arguments)
          raise shutdown
        end

        expect { described_class.call(params:) }.to raise_error(Sidekiq::Shutdown) do |error|
          expect(error).to equal(shutdown)
        end

        expect(first_execution.reload).to be_success
        expect(first_execution.execution_data.reload.attributes).to eq(checkpoint)
      end

      it "deduplicates completed jobs while preserving creation events and rate-limit capacity" do
        RateLimiter.enable
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 2
        repeated_result = nil
        messages =
          MessageBus.track_publish(
            DiscourseWorkflows::ExecutionProgressPublisher::EXECUTIONS_CHANNEL,
          ) do
            result
            repeated_result = described_class.call(params:)
          end
        distinct_result =
          described_class.call(params: params.merge(job_id: "distinct-workflow-job"))

        expect([result, repeated_result, distinct_result]).to all(run_successfully)
        expect(repeated_result[:execution]).to eq(result[:execution])
        expect(workflow.executions).to contain_exactly(
          result[:execution],
          distinct_result[:execution],
        )
        expect(workflow.executions).to all(be_success)
        expect(
          messages.map(&:data).select { |message| message[:type] == "execution_created" },
        ).to contain_exactly(include(execution: include(id: result[:execution].id)))
        expect(a_request(:post, effect_url)).to have_been_made.twice
      ensure
        RateLimiter.disable
      end

      it "excludes rate-limited jobs from execution statistics", :aggregate_failures do
        RateLimiter.enable
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1
        expect(result[:execution]).to be_success
        limited_result = nil

        expect {
          limited_result =
            described_class.call(params: params.merge(job_id: "limited-workflow-job"))
        }.not_to change {
          DiscourseWorkflows::ExecutionStat.where(workflow_id: workflow.id).sum(:total_runs)
        }

        expect(limited_result).to run_successfully
        expect(limited_result[:execution]).to be_rate_limited
        expect(a_request(:post, effect_url)).to have_been_made.once
      ensure
        RateLimiter.disable
      end

      it "executes on redelivery after Redis fails before node execution" do
        RateLimiter.enable
        redis = Discourse.redis.without_namespace
        redis.stubs(:evalsha).raises(Redis::CannotConnectError)

        expect(result).to fail_to_find_a_model(:execution)
        redis.unstub(:evalsha)
        retried_result = described_class.call(params:)

        expect(retried_result).to run_successfully
        expect(retried_result[:execution]).to be_success
        expect(a_request(:post, effect_url)).to have_been_made.once
      ensure
        RateLimiter.disable
      end

      it "executes once when duplicate deliveries compete for the final rate-limit slot" do
        RateLimiter.enable
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1
        delivery_params = params.dup
        workflow_limit_key = "discourse_workflows_workflow_#{workflow.id}"
        first_checked_quota = Queue.new
        continue_first = Queue.new
        duplicate_progress = Queue.new
        workers = []
        first_paused = false
        thread_timeout = 5.seconds

        %i[evalsha eval].each do |command|
          allow(Discourse.redis.without_namespace).to receive(
            command,
          ).and_wrap_original do |original, *arguments|
            response = original.call(*arguments)
            delivery = Thread.current[:workflow_delivery]

            if delivery == :first && !first_paused &&
                 Array(arguments[1]).any? { |key| key.end_with?(workflow_limit_key) }
              first_paused = true
              first_checked_quota << :paused
              continue_first.pop
            elsif delivery == :duplicate && response.nil?
              duplicate_progress << :blocked
            end

            response
          end
        end

        workers << Thread.new do
          Thread.current[:workflow_delivery] = :first
          described_class.call(params: delivery_params)
        end
        expect(first_checked_quota.pop(timeout: thread_timeout)).to eq(:paused)

        workers << Thread.new do
          Thread.current[:workflow_delivery] = :duplicate
          described_class.call(params: delivery_params)
        ensure
          duplicate_progress << :finished
        end
        expect(duplicate_progress.pop(timeout: thread_timeout)).to be_in(%i[blocked finished])
        continue_first << :continue
        results =
          workers.map do |worker|
            expect(worker.join(thread_timeout)).to eq(worker)
            worker.value
          end

        expect(results).to all(run_successfully)
        expect(results.map { |delivery_result| delivery_result[:execution].id }.uniq).to eq(
          [workflow.executions.sole.id],
        )
        expect(workflow.executions.sole).to be_success
        expect(a_request(:post, effect_url)).to have_been_made.once
      ensure
        continue_first << :continue if continue_first
        workers&.each do |worker|
          worker.kill if worker.alive?
          worker.join
        end
        RateLimiter.disable
      end
    end

    context "when user_id is provided" do
      fab!(:execution_user, :user)
      let(:params) do
        { workflow_id: workflow.id, trigger_node_id: "trigger-1", user_id: execution_user.id }
      end

      it { is_expected.to run_successfully }

      it "fetches the correct user" do
        expect(result[:user]).to eq(execution_user)
      end
    end
  end
end
