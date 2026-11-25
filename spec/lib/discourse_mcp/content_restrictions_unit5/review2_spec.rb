# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Tag, "#update / #update!" do
  include_context "with unit five content guards"

  fab!(:tag) { Fabricate(:tag, id: 113_577_001, name: "u5-r2-source") }
  fab!(:target) { Fabricate(:tag, id: 113_577_002, name: "u5-r2-target") }

  %i[update update!].each do |operation|
    %i[allow deny].each do |side|
      it "[cr-u5] rejects #{operation} converting the #{side}-listed tag to a synonym" do
        protect_targets(side, tag_ids: [tag.id])

        aggregate_failures do
          if operation == :update!
            expect { tag.update!(target_tag: target) }.to raise_error(
              ActiveRecord::RecordInvalid,
            ) { |error| expect_rule_explanation(error.message) }
          else
            expect(tag.update(target_tag: target)).to eq(false),
            "PLAIN SYNONYM UPDATE: listed tag conversion succeeded"
          end
          expect_rule_explanation(tag.errors.full_messages.join(" "))
          expect(tag.reload.target_tag_id).to be_nil
        end
      end
    end

    it "[cr-u5] permits #{operation} converting an unlisted tag to a listed target" do
      protect_targets(:deny, tag_ids: [target.id])

      expect(tag.public_send(operation, target_tag: target)).to eq(true)
      expect(tag.reload.target_tag_id).to eq(target.id)
    end

    it "[cr-u5] preserves #{operation} synonym conversion with no rule rows" do
      expect(McpContentRule.count).to eq(0)

      expect(tag.public_send(operation, target_tag: target)).to eq(true)
      expect(tag.reload.target_tag_id).to eq(target.id)
    end
  end
end

describe McpContentRule, "#save during target destruction" do
  self.use_transactional_tests = false

  include McpContentRestrictionsUnit5

  before do
    expect(McpContentRule.count).to eq(0)
    SiteSetting.tagging_enabled = true
    Jobs.run_later!
  end

  %i[tag category].each do |kind|
    %i[allow deny].each do |side|
      it "[cr-u5] saves the #{side} rule while its listed #{kind} survives" do
        target =
          if kind == :tag
            Fabricate(:tag, id: 113_578_003, name: "u5-r2-surviving-tag")
          else
            Fabricate(:category, id: 113_578_004, user: Discourse.system_user)
          end
        rule = nil

        begin
          rule =
            protect_targets(
              side,
              category_ids: kind == :category ? [target.id] : [],
              tag_ids: kind == :tag ? [target.id] : [],
            )

          expect(McpContentRule.exists?(rule.id)).to eq(true)
          expect(target.class.exists?(target.id)).to eq(true)
        ensure
          McpContentRule.where(id: rule.id).delete_all if rule
          target.class.find_by(id: target.id)&.destroy!
        end
      end

      %i[rule_first destroy_first].each do |commit_order|
        it "[cr-u5] refuses the #{side} rule racing #{kind} destruction with #{commit_order} commit release" do
          target =
            if kind == :tag
              Fabricate(:tag, id: 113_578_001, name: "u5-r2-racing-tag")
            else
              Fabricate(:category, id: 113_578_002, user: Discourse.system_user)
            end
          rule =
            McpContentRule.new(
              rule_kind: "forum_content",
              config: {
                allow: {
                  mode: side == :allow ? "selected" : "all",
                  category_ids: kind == :category && side == :allow ? [target.id] : [],
                  tag_ids: kind == :tag && side == :allow ? [target.id] : [],
                },
                deny: {
                  category_ids: kind == :category && side == :deny ? [target.id] : [],
                  tag_ids: kind == :tag && side == :deny ? [target.id] : [],
                },
              },
            )
          pool = ActiveRecord::Base.connection_pool
          worker_pid = Queue.new
          progress = Queue.new
          release_commit = Queue.new
          saved = nil
          visible_before_save = nil
          worker = nil

          begin
            pool.with_connection do |destroy_connection|
              expect(destroy_connection.transaction_open?).to eq(false)
              destroy_pid = destroy_connection.select_value("SELECT pg_backend_pid()")
              destroy_connection.transaction do
                target.destroy!
                expect(target).to be_destroyed

                worker =
                  Thread.new do
                    pool.with_connection do |rule_connection|
                      worker_pid << rule_connection.select_value("SELECT pg_backend_pid()")
                      rule_connection.transaction do
                        rule_connection.execute("SET LOCAL statement_timeout = '10s'")
                        visible_before_save = target.class.exists?(target.id)
                        saved = rule.save
                        progress << :saved
                        if commit_order == :destroy_first
                          raise "Rule commit latch timed out" unless release_commit.pop(timeout: 10)
                        end
                      end
                      progress << :committed
                    end
                  end
                rule_pid = worker_pid.pop(timeout: 5)
                expect(rule_pid).to be_present
                expect(rule_pid).not_to eq(destroy_pid)
                deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5

                # Release a synchronized save once PostgreSQL reports it waiting
                # on this destroy, rather than mistaking a slow worker for a lock.
                loop do
                  worker.value unless worker.alive?
                  phase = progress.pop(timeout: 0.01)
                  break if phase == (commit_order == :rule_first ? :committed : :saved)
                  break if destroy_connection.select_value(<<~SQL)
                    SELECT #{destroy_pid.to_i} = ANY(pg_blocking_pids(#{rule_pid.to_i}))
                  SQL
                  if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
                    raise "Rule save neither reached its commit latch nor waited on the destroy"
                  end
                end
              end
            end
            release_commit << true
            raise "Rule worker did not finish" unless worker.join(10)
            worker.value

            aggregate_failures do
              expect(visible_before_save).to eq(true)
              expect(target.class.exists?(target.id)).to eq(false)
              expect(saved).to eq(false),
              "RULE/DESTROY RACE: both target destroy and referencing rule save committed"
              expect(McpContentRule.exists?(rule.id)).to eq(false)
              expect(rule.errors.full_messages).to be_present
            end
          ensure
            release_commit << true
            begin
              if worker
                worker.kill unless worker.join(10)
                worker.join
              end
            ensure
              McpContentRule.where(id: rule.id).delete_all if rule.id
              target.class.find_by(id: target.id)&.destroy!
            end
          end
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
