# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe McpContentRule, "#save with obsolete target state" do
  include_context "with unit five content guards"

  %i[tag category].each do |kind|
    %i[allow deny].each do |side|
      it "[cr-u5] refuses a stale #{side} config reintroducing a destroyed #{kind}" do
        target = Fabricate(kind, id: 113_580_001)
        key = kind == :tag ? "tag_ids" : "category_ids"
        original = protect_targets(side, **{ key.to_sym => [target.id] })
        stale = McpContentRule.find(original.id)
        replacement = original.config.deep_dup
        replacement[side.to_s][key] = []
        McpContentRule.find(original.id).update!(config: replacement)
        target.destroy!
        stale.config["allow"]["mode"] = side == :allow ? "all" : "selected"

        aggregate_failures do
          expect(stale.save).to eq(false), "STALE CONFIG: destroyed target was reintroduced"
          expect(stale.errors.full_messages).to be_present
          expect(original.reload.config.dig(side.to_s, key)).to eq([])
          expect(target.class.exists?(target.id)).to eq(false)
        end
      end

      it "[cr-u5] refuses switching to forum_content with a missing #{side} #{kind}" do
        key = kind == :tag ? "tag_ids" : "category_ids"
        config = {
          allow: {
            mode: side == :allow ? "selected" : "all",
            category_ids: [],
            tag_ids: [],
          },
          deny: {
            category_ids: [],
            tag_ids: [],
          },
        }.deep_stringify_keys
        config[side.to_s][key] = [113_580_099]
        row = McpContentRule.create!(rule_kind: "review3:old", config: config)

        aggregate_failures do
          expect(row.update(rule_kind: "forum_content")).to eq(false),
          "RULE KIND SWITCH: missing target was admitted"
          expect(row.errors.full_messages).to be_present
          expect(row.reload.rule_kind).to eq("review3:old")
          expect(McpContentRule.exists?(rule_kind: "forum_content")).to eq(false)
        end
      end
    end
  end
end

describe CategoryDestroyer, ".destroy racing CategoryUpdater.update" do
  include McpContentRestrictionsUnit5

  self.use_transactional_tests = false

  [false, true].each do |with_rule|
    it "[cr-u5] completes delete racing reparent #{with_rule ? "with" : "without"} rule rows without deadlock" do
      expect(McpContentRule.count).to eq(0)
      Jobs.run_later!
      category = Fabricate(:category, id: 113_580_010, user: Discourse.system_user)
      parent = Fabricate(:category, id: 113_580_011, user: Discourse.system_user)
      rule = protect_targets(:deny) if with_rule
      start_update = Queue.new
      ready = Queue.new
      pool = ActiveRecord::Base.connection_pool
      results = {}
      worker = nil
      observer = nil
      destroy_thread = Thread.current

      begin
        worker =
          Thread.new do
            pool.with_connection do |connection|
              loaded = Category.find(category.id)
              ready << connection.select_value("SELECT pg_backend_pid()")
              raise "Update latch timed out" unless start_update.pop(timeout: 10)
              connection.transaction do
                connection.execute("SET LOCAL statement_timeout = '10s'")
                results[:updated] = CategoryUpdater.update(
                  Discourse.system_user.guardian,
                  loaded,
                  parent_category_id: parent.id,
                )
              end
            rescue StandardError => error
              results[:update_error] = error
            end
          end
        update_pid = ready.pop(timeout: 5)
        expect(update_pid).to be_present

        pool.with_connection do |connection|
          destroy_pid = connection.select_value("SELECT pg_backend_pid()")
          expect(update_pid).not_to eq(destroy_pid)
          paused = false
          observer =
            ActiveSupport::Notifications.subscribe("sql.active_record") do |*, event|
              next unless Thread.current == destroy_thread && !paused
              next unless event[:sql].match?(/SELECT.*"categories".*FOR UPDATE/m)
              paused = true
              start_update << true
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
              loop do
                raise "Update worker exited before blocking" unless worker.alive?
                if connection.select_value(
                     "SELECT #{destroy_pid.to_i} = ANY(pg_blocking_pids(#{update_pid.to_i}))",
                   )
                  break
                end
                if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
                  raise "Update never waited on delete"
                end
                Thread.pass
              end
            end
          begin
            connection.transaction do
              connection.execute("SET LOCAL statement_timeout = '10s'")
              results[:deleted] = CategoryDestroyer.destroy(
                Discourse.system_user.guardian,
                category,
              )
            end
          rescue StandardError => error
            results[:delete_error] = error
          end
          expect(paused).to eq(true), "Delete never reached the category row-lock interleaving"
        end
        raise "Update worker did not finish" unless worker.join(12)
        worker.value

        aggregate_failures do
          expect(results.values.grep(ActiveRecord::Deadlocked)).to eq([]),
          "DELETE/REPARENT DEADLOCK: #{results.slice(:delete_error, :update_error).inspect}"
          expect(results[:delete_error]).to be_nil
          if results[:update_error]
            expect(results[:update_error]).to be_a(ActiveRecord::RecordNotFound)
          else
            expect(results[:updated]).to eq(true).or(eq(false))
          end
          expect(results[:deleted]).to be_destroyed
          expect(Category.exists?(category.id)).to eq(false)
          expect(Category.exists?(parent.id)).to eq(true)
        end
      ensure
        ActiveSupport::Notifications.unsubscribe(observer) if observer
        start_update << true
        worker.kill if worker && !worker.join(12)
        worker&.join
        McpContentRule.where(id: rule.id).delete_all if rule
        Category.find_by(id: category.id)&.destroy!
        Category.find_by(id: parent.id)&.destroy!
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
