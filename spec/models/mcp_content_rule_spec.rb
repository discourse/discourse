# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe McpContentRule do
  describe Tag do
    include_context "with MCP content rule targets"

    fab!(:tag) { Fabricate(:tag, id: 113_570_001, name: "u5-protected") }
    fab!(:other_tag) { Fabricate(:tag, id: 113_570_002, name: "u5-unreferenced") }

    describe "#destroy" do
      %i[allow deny].each do |side|
        it "raises with a rule explanation when directly destroying the #{side}-referenced tag" do
          topic = Fabricate(:topic, tags: [tag])
          group = Fabricate(:tag_group, tags: [tag])
          protect_targets(side, tag_ids: [tag.id])

          aggregate_failures do
            expect { tag.destroy }.to raise_error(StandardError) { |error|
              expect_rule_explanation(error.message)
            }
            expect(Tag.exists?(tag.id)).to eq(true), "TAG DESTROY: referenced tag disappeared"
            expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
            expect(group.reload.tags.pluck(:id)).to eq([tag.id])
          end
        end

        it "propagates the #{side}-referenced tag destroy failure through an outer transaction" do
          topic = Fabricate(:topic, tags: [tag])
          protect_targets(side, tag_ids: [tag.id])

          aggregate_failures do
            expect do
              Tag.transaction do
                tag.destroy
                other_tag.update!(description: "The outer transaction continued")
              end
            end.to raise_error(StandardError) { |error| expect_rule_explanation(error.message) }
            expect(Tag.exists?(tag.id)).to eq(true), "OUTER TRANSACTION: referenced tag disappeared"
            expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
            expect(other_tag.reload.description).to be_nil,
            "OUTER TRANSACTION: failed destroy was silently swallowed"
          end
        end

        it "preserves the #{side}-referenced synonym when its canonical tag is destroyed" do
          tag.update!(target_tag: other_tag)
          protect_targets(side, tag_ids: [tag.id])

          aggregate_failures do
            expect { other_tag.destroy }.to raise_error(StandardError) { |error|
              expect_rule_explanation(error.message)
            }
            expect(Tag.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
              tag.id,
              other_tag.id,
            )
            expect(Tag.find_by(id: tag.id)&.target_tag_id).to eq(other_tag.id)
          end
        end
      end

      it "destroys tags and their synonyms inside an outer transaction with no rules" do
        tag.update!(target_tag: other_tag)
        expect(McpContentRule.count).to eq(0)

        Tag.transaction { other_tag.destroy }

        expect(Tag.where(id: [tag.id, other_tag.id])).to be_empty
      end

      it "destroys an unreferenced tag while another tag is protected" do
        protect_targets(:deny, tag_ids: [tag.id])

        other_tag.destroy

        expect(Tag.where(id: [tag.id, other_tag.id]).pluck(:id)).to eq([tag.id])
      end
    end

    describe ".unused" do
      %i[allow deny].each do |side|
        it "excludes a topicless #{side}-referenced tag while retaining unreferenced unused tags" do
          expect(tag.topics).to be_empty
          expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
            tag.id,
            other_tag.id,
          )
          protect_targets(side, tag_ids: [tag.id])

          expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to eq([other_tag.id]),
          "UNUSED SCOPE: referenced tag remains eligible for cleanup"
        end
      end

      it "includes both topicless tags in unused with no rules" do
        expect(McpContentRule.count).to eq(0)
        expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
          tag.id,
          other_tag.id,
        )
      end
    end
  end

  describe Tag, "#update / #update!" do
    include_context "with MCP content rule targets"

    fab!(:tag) { Fabricate(:tag, id: 113_577_001, name: "u5-r2-source") }
    fab!(:target) { Fabricate(:tag, id: 113_577_002, name: "u5-r2-target") }

    %i[update update!].each do |operation|
      %i[allow deny].each do |side|
        it "rejects #{operation} converting the #{side}-listed tag to a synonym" do
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

      it "permits #{operation} converting an unlisted tag to a listed target" do
        protect_targets(:deny, tag_ids: [target.id])

        expect(tag.public_send(operation, target_tag: target)).to eq(true)
        expect(tag.reload.target_tag_id).to eq(target.id)
      end

      it "preserves #{operation} synonym conversion with no rule rows" do
        expect(McpContentRule.count).to eq(0)

        expect(tag.public_send(operation, target_tag: target)).to eq(true)
        expect(tag.reload.target_tag_id).to eq(target.id)
      end
    end
  end

  describe DiscourseTagging, ".add_or_create_synonyms" do
    include_context "with MCP content rule targets"

    fab!(:tag) { Fabricate(:tag, id: 113_571_001, name: "u5-synonym-source") }
    fab!(:target) { Fabricate(:tag, id: 113_571_002, name: "u5-synonym-target") }

    %i[allow deny].each do |side|
      %i[id name].each do |input|
        it "refuses conversion of the #{side}-referenced tag to a synonym by #{input}" do
          topic = Fabricate(:topic, tags: [tag])
          protect_targets(side, tag_ids: [tag.id])
          arguments =
            input == :id ? { synonym_tag_ids: [tag.id] } : { new_synonym_names: [tag.name.upcase] }

          result = DiscourseTagging.add_or_create_synonyms(target, **arguments)

          aggregate_failures do
            expect(result).to be_a(Hash), "SYNONYM SERVICE: referenced tag conversion succeeded"
            expect_rule_explanation(result[tag.name].to_s) if result.is_a?(Hash)
            expect(tag.reload.target_tag_id).to be_nil
            expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
          end
        end
      end
    end

    it "converts a tag and transfers its topic tags with no rules" do
      topic = Fabricate(:topic, tags: [tag])
      expect(McpContentRule.count).to eq(0)

      expect(DiscourseTagging.add_or_create_synonyms(target, synonym_tag_ids: [tag.id])).to eq(true)
      expect(tag.reload.target_tag_id).to eq(target.id)
      expect(topic.reload.tags.pluck(:id)).to eq([target.id])
    end

    it "permits an unreferenced tag to become a synonym of a referenced target" do
      protect_targets(:deny, tag_ids: [target.id])

      expect(DiscourseTagging.add_or_create_synonyms(target, new_synonym_names: [tag.name])).to eq(
        true,
      )
      expect(tag.reload.target_tag_id).to eq(target.id)
    end
  end

  describe Jobs::CleanUpTags, "#execute" do
    include_context "with MCP content rule targets"

    fab!(:tag) { Fabricate(:tag, id: 113_572_001, created_at: 1.hour.ago) }
    fab!(:other_tag) { Fabricate(:tag, id: 113_572_002, created_at: 1.hour.ago) }

    before { SiteSetting.automatically_clean_unused_tags = true }

    %i[allow deny].each do |side|
      it "keeps a topicless #{side}-referenced tag while the scheduled job deletes an unused peer" do
        expect(tag.topics).to be_empty
        protect_targets(side, tag_ids: [tag.id])
        tag_ids = [tag.id, other_tag.id]
        protected_id = tag.id

        described_class.new.execute({})

        expect(Tag.where(id: tag_ids).pluck(:id)).to eq([protected_id]),
        "CLEANUP JOB: referenced tag was deleted or unreferenced cleanup was blocked"
      end
    end

    it "deletes both old unused tags through the scheduled job with no rules" do
      expect(McpContentRule.count).to eq(0)
      tag_ids = [tag.id, other_tag.id]

      described_class.new.execute({})

      expect(Tag.where(id: tag_ids)).to be_empty
    end
  end

  describe Category do
    include_context "with MCP content rule targets"

    fab!(:root) { Fabricate(:category_with_definition, id: 113_575_001, user: admin) }

    describe "#destroy" do
      %i[allow deny].each do |side|
        it "returns model errors when directly destroying the #{side}-referenced category" do
          topic_id = root.topic_id
          timer = Fabricate(:topic_timer, category: root)
          protect_targets(side, category_ids: [root.id])

          result = root.destroy

          aggregate_failures do
            expect(result).to eq(false), "CATEGORY MODEL DELETE: referenced category destroyed"
            expect_rule_explanation(root.errors.full_messages.join(" "))
            expect(Category.exists?(root.id)).to eq(true)
            expect(TopicTimer.exists?(timer.id)).to eq(true)
            expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
          end
        end
      end

      it "preserves a denied grandchild and its definition inside an outer destroy transaction" do
        child = Fabricate(:category, parent_category: root, user: admin)
        grandchild = Fabricate(:category_with_definition, parent_category: child, user: admin)
        topic_id = grandchild.topic_id
        timer = Fabricate(:topic_timer, category: grandchild)
        protect_targets(:deny, category_ids: [root.id])
        result = nil

        Category.transaction { result = grandchild.destroy }

        aggregate_failures do
          expect(result).to eq(false), "CATEGORY OUTER DELETE: denied grandchild destroyed"
          expect_rule_explanation(grandchild.errors.full_messages.join(" "))
          expect(Category.exists?(grandchild.id)).to eq(true)
          expect(TopicTimer.exists?(timer.id)).to eq(true)
          expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
        end
      end

      it "destroys a category and its dependent timer inside an outer transaction with no rules" do
        topic_id = root.topic_id
        timer = Fabricate(:topic_timer, category: root)
        expect(McpContentRule.count).to eq(0)

        Category.transaction { root.destroy }

        expect(Category.exists?(root.id)).to eq(false)
        expect(TopicTimer.exists?(timer.id)).to eq(false)
        expect(Topic.with_deleted.find(topic_id).deleted_at).to be_present
      end
    end

    describe "#update" do
      it "returns model errors when directly detaching a denied grandchild" do
        child = Fabricate(:category, parent_category: root, user: admin)
        grandchild = Fabricate(:category, parent_category: child, user: admin)
        protect_targets(:deny, category_ids: [root.id])

        result = grandchild.update(parent_category_id: nil)

        aggregate_failures do
          expect(result).to eq(false), "CATEGORY MODEL MOVE: denied grandchild escaped"
          expect_rule_explanation(grandchild.errors.full_messages.join(" "))
          expect(grandchild.reload.parent_category_id).to eq(child.id)
        end
      end
    end
  end

  describe CategoryUpdater, ".update" do
    include_context "with MCP content rule targets"

    it "returns category errors from the real updater when moving a denied branch outside" do
      root = Fabricate(:category, user: admin)
      branch = Fabricate(:category, parent_category: root, user: admin)
      leaf = Fabricate(:category, parent_category: branch, user: admin)
      outside = Fabricate(:category, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      result = CategoryUpdater.update(admin.guardian, branch, parent_category_id: outside.id)

      aggregate_failures do
        expect(result).to eq(false), "CATEGORY UPDATER: denied branch escaped"
        expect_rule_explanation(branch.errors.full_messages.join(" "))
        expect(branch.reload.parent_category_id).to eq(root.id)
        expect(leaf.reload.parent_category_id).to eq(branch.id)
      end
    end

    it "lets the updater move a branch with no rules" do
      root = Fabricate(:category, user: admin)
      branch = Fabricate(:category, parent_category: root, user: admin)
      outside = Fabricate(:category, user: admin)
      expect(McpContentRule.count).to eq(0)

      expect(CategoryUpdater.update(admin.guardian, branch, parent_category_id: outside.id)).to eq(
        true,
      )
      expect(branch.reload.parent_category_id).to eq(outside.id)
    end
  end

  describe CategoryDestroyer, ".destroy racing CategoryUpdater.update" do
    include McpContentRuleTargetHelpers

    self.use_transactional_tests = false

    [false, true].each do |with_rule|
      it "completes delete racing reparent #{with_rule ? "with" : "without"} rule rows without deadlock" do
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

  describe "#save during target destruction" do
    self.use_transactional_tests = false

    include McpContentRuleTargetHelpers

    before do
      expect(McpContentRule.count).to eq(0)
      SiteSetting.tagging_enabled = true
      Jobs.run_later!
    end

    %i[tag category].each do |kind|
      %i[allow deny].each do |side|
        it "saves the #{side} rule while its listed #{kind} survives" do
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
          it "refuses the #{side} rule racing #{kind} destruction with #{commit_order} commit release" do
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
                            unless release_commit.pop(timeout: 10)
                              raise "Rule commit latch timed out"
                            end
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

  describe "#save with obsolete target state" do
    include_context "with MCP content rule targets"

    %i[tag category].each do |kind|
      %i[allow deny].each do |side|
        it "refuses a stale #{side} config reintroducing a destroyed #{kind}" do
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

        it "refuses switching to forum_content with a missing #{side} #{kind}" do
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
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
