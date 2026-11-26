# frozen_string_literal: true

require "time"
require_relative "runner"
require_relative "customer_report"
require_relative "content_transfer"
require_relative "matched_activity"

module BulkImport::DiscourseMerge
  class Verifier
    def initialize(importer, plan, run_dir, progress: nil)
      @importer, @plan, @run_dir = importer, plan, run_dir
      @maps = importer.maps
      @keys = importer.category_keys
      @checks = {}
      @progress = progress
    end

    def check(name)
      result = yield
      @checks[name] = !!result
      raise Error, "Verification failed: #{name}" unless result
    rescue Error
      @checks[name] = false
      Artifacts.write(@run_dir.join("verification.json"), JSON.pretty_generate(@checks))
      raise
    end

    def run!(evidence_sha256: nil)
      check("account_outcomes") { account_outcomes_match? } if @importer.account_outcomes
      if @plan.data["merge_member_activity"]
        check("matched_member_visit_dates") do
          matches = @plan.data.fetch("source_findings").fetch("account_matches")
          members =
            matches.to_h do |row|
              [Integer(row.fetch("source_user_id")), row.fetch("destination_user_id")]
            end
          MatchedActivity.visit_dates_present?(@importer.source_raw_connection, members)
        end
        check("matched_member_summaries") do
          ids = @plan.data.fetch("matched_avatars").pluck("destination_user_id").sort
          expected = @importer.matched_summaries
          ids == expected.keys.map(&:to_i).sort && UserStat.where(user_id: ids).count == ids.size &&
            UserStat
              .where(user_id: ids)
              .all? do |stat|
                fields = expected.fetch(stat.user_id.to_s)
                %w[days_visited time_read topics_entered posts_read_count].all? do |field|
                  stat[field] == fields.fetch(field)
                end
              end
        end
      end
      check("complete_topic_map") do
        @maps[:topics].keys.to_set == @plan.included_ids &&
          @maps[:topics].values.uniq.size == @maps[:topics].size
      end
      check("excluded_topics_unmapped") { (@maps[:topics].keys.to_set & @plan.excluded_ids).empty? }
      @maps[:topics].each_slice(1000) do |pairs|
        ids = pairs.map(&:last)
        actual = Topic.with_deleted.where(id: ids).index_by(&:id)
        tagged_ids =
          pairs.filter_map { |original, id| id if @plan.topic(original).fetch("add_tags").any? }
        tags =
          TopicTag
            .where(topic_id: tagged_ids)
            .joins(:tag)
            .pluck(:topic_id, "tags.name")
            .group_by(&:first)
            .transform_values { |rows| rows.map(&:last) }
        pairs.each do |original, id|
          instruction = @plan.topic(original)
          topic = actual.fetch(id)
          check("topic_#{original}_destination") do
            topic.category_id ==
              (instruction["destination_key"] && @keys.fetch(instruction["destination_key"]))
          end
          check("topic_#{original}_archetype") do
            topic.archetype ==
              instruction.fetch(
                "source_archetype",
                instruction["action"] == "copy_private_message" ? "private_message" : "regular",
              )
          end
          instruction
            .fetch("source_state")
            .each do |field, expected|
              value = topic.public_send(field)
              check("topic_#{original}_#{field}") do
                if field.end_with?("_at")
                  value.nil? == expected.nil? &&
                    (value.nil? || value.to_r == Time.parse(expected).to_r)
                else
                  value == expected
                end
              end
            end
          check("topic_#{original}_tags") do
            (instruction.fetch("add_tags") - tags.fetch(topic.id, [])).empty?
          end
        end
      end
      verify_report_categories = @plan.data.key?("source_categories")
      categories_by_path = @plan.categories.values.index_by { |item| item.fetch("path") }
      @plan.categories.each_value do |item|
        existing = item["operation"] == "preserve_existing"
        next if existing && !verify_report_categories
        category = Category.find(@keys.fetch(item.fetch("key")))
        check("category_#{category.id}_name") { category.name == item.fetch("path").last }
        parent =
          if item.fetch("path").length > 1
            parent_item = categories_by_path.fetch(item.fetch("path")[0...-1])
            @keys.fetch(parent_item.fetch("key"))
          end
        check("category_#{category.id}_parent") { category.parent_category_id == parent }
        if verify_report_categories
          check("category_#{category.id}_read_access") do
            category.read_restricted == (item.fetch("access") == "restricted")
          end
        end
        next if existing
        check("category_#{category.id}_access") do
          expected =
            GroupMapping
              .grants(item.fetch("grants"), @maps[:groups])
              .map { |grant| [grant.fetch(:group_id), grant.fetch(:permission_type)] }
              .to_set
          CategoryGroup.where(category_id: category.id).pluck(:group_id, :permission_type).to_set ==
            expected
        end
        check("category_#{category.id}_definition") do
          category.topic_id &&
            Topic.with_deleted.where(id: category.topic_id, category_id: category.id).exists?
        end
      end
      if verify_report_categories
        check("complete_category_map") do
          @keys.keys.to_set == @plan.categories.keys.to_set && @keys.values.uniq.size == @keys.size
        end
        check("destination_login_required") do
          SiteSetting.login_required == @plan.data.fetch("login_required").fetch("destination")
        end
      end
      check("final_category_count") do
        Category.unscoped.count == @plan.data.dig("summary", "projected_final_categories")
      end
      check("original_categories_preserved") do
        Category.where(
          id: @plan.data.fetch("existing_destination_category_ids_to_preserve"),
        ).count == @plan.data.fetch("existing_destination_category_ids_to_preserve").size
      end
      verify_staff_roles if @plan.data.dig("policy", "source_staff_roles")
      verify_groups
      verify_group_access
      if (decisions = @plan.data["matched_avatars"])
        check("matched_member_avatars") { MatchedAvatars.verify!(decisions, @maps) }
      end
      verify_posts
      if @maps.key?(:post_revisions)
        check("complete_revision_history") { verify_revision_history }
      elsif (entries = @plan.data["preserved_broken_revision_uploads"])
        check("reviewed_revision_media") { verify_reviewed_revisions(entries) }
      end
      verify_access
      if @plan.data.dig("upload_policy", "mode") == "preuploaded"
        check("prepared_media") { verify_prepared_media }
      else
        verify_uploads
      end
      verify_solved
      verify_likes
      if (decisions = @plan.data["content"])
        check("reviewed_destination_content_settings") do
          @plan.data.fetch("content_settings") == ContentInventory.destination_settings
        end
        check("reviewed_content") do
          @content_summary =
            ContentTransfer.new(
              @importer.source_raw_connection,
              ActiveRecord::Base.connection.raw_connection,
              @maps,
              @keys,
              @importer.references(@plan),
              @importer.content_ids,
            ).verify(decisions)
        end
      end
      check("historical_bots_inactive_and_isolated") do
        @maps[:users]
          .select { |original, _| original < -2 }
          .all? do |_, id|
            user = User.find(id)
            id > 0 && user.staged && !user.active && !user.admin && !user.moderator
          end
      end
      check("mail_and_workers_disabled") do
        SiteSetting.disable_emails == "yes" && Environment.check!
      end
      yield self if block_given?
      count = @checks.size
      if evidence_sha256
        @checks["evidence_sha256"] = evidence_sha256
        @checks["report_summary"] = ReportSummary.new(@plan).build(
          posts: @maps.fetch(:posts).size,
          uploads: @maps.fetch(:uploads).size,
        )
      end
      @checks["report_summary"]["content"] = @content_summary if evidence_sha256 && @content_summary
      @checks["status"] = "passed"
      Artifacts.write(@run_dir.join("verification.json"), JSON.pretty_generate(@checks))
      puts "DISCOURSE_MERGE_VERIFICATION_SUCCESS"
      @progress&.say("Passed #{count} verification checks")
    rescue StandardError, Interrupt => error
      @checks["status"] = "failed"
      @checks["error"] = error.message
      Artifacts.write(@run_dir.join("verification.json"), JSON.pretty_generate(@checks))
      raise
    end

    def account_outcomes_match?
      expected = @importer.account_outcomes.dup
      matches =
        @plan
          .data
          .fetch("source_findings")
          .fetch("account_matches")
          .to_h { |row| row.fetch_values("source_user_id", "destination_user_id") }
      SourceRows.each_batch(
        @importer.source_raw_connection,
        "SELECT id, username FROM users WHERE id > 0",
      ) do |rows|
        names =
          User
            .unscoped
            .where(id: rows.filter_map { |row| @maps[:users][Integer(row["id"])] })
            .pluck(:id, :username)
            .to_h
        rows.each do |row|
          original = Integer(row.fetch("id"))
          target = @maps[:users][original]
          next unless target
          final = names.fetch(target)
          name = row.fetch("username")
          matched = matches.delete(original)
          return false if matched && matched != target
          next if !matched && name == final
          unless expected.delete(original.to_s) ==
                   {
                     "source_username" => name,
                     "final_username" => final,
                     "reason" => matched ? "email_match" : "username_collision",
                   }
            return false
          end
        end
      end
      expected.empty? && matches.empty?
    end

    def verify_posts
      preserved_html =
        @plan.data.fetch("format_version") >= 3 &&
          %w[preuploaded preserve_remote].include?(@plan.data.dig("upload_policy", "mode"))
      sql = <<~SQL
        SELECT id, topic_id, user_id, created_at, updated_at, deleted_at, hidden, user_deleted, locked_by_id, raw#{", cooked" if preserved_html}
        FROM posts WHERE topic_id IN (#{@plan.sql_ids(@plan.included_ids)})
      SQL
      count = 0
      SourceRows.each_batch(@importer.source_raw_connection, sql) do |rows|
        ids =
          rows.map do |row|
            @maps[:posts].fetch(row.fetch("id").to_i) do
              raise Error, "Verification failed: complete_post_map"
            end
          end
        actual = Post.with_deleted.where(id: ids).index_by(&:id)
        rows.each do |source|
          post = actual.fetch(@maps[:posts].fetch(source.fetch("id").to_i))
          check("post_#{source["id"]}_state") do
            post.topic_id == @maps[:topics].fetch(source.fetch("topic_id").to_i) &&
              post.user_id ==
                (source["user_id"] && @maps[:users].fetch(source.fetch("user_id").to_i)) &&
              %w[created_at updated_at deleted_at].all? do |field|
                value = post.public_send(field)
                value.nil? == source[field].nil? &&
                  (value.nil? || value.to_r == Time.parse(source.fetch(field)).to_r)
              end && post.hidden == (source["hidden"] == "t") &&
              post.user_deleted == (source["user_deleted"] == "t")
          end
          check("post_#{source["id"]}_lock") do
            post.locked_by_id == References.post_locker(source["locked_by_id"], @maps.fetch(:users))
          end
          if preserved_html && source["cooked"].present?
            check("post_#{source["id"]}_cooked") do
              post.cooked ==
                @importer.references(@plan).rewrite(
                  source.fetch("cooked"),
                  cooked: true,
                  source_post_id: source.fetch("id").to_i,
                )
            end
          end
          check("post_#{source["id"]}_body") do
            post.raw ==
              @importer.references(@plan).rewrite(
                source.fetch("raw"),
                source_post_id: source.fetch("id").to_i,
              )
          end
        end
        count += rows.size
      end
      check("complete_post_map") do
        count == @maps[:posts].size && @maps[:posts].values.uniq.size == count
      end
    end

    def verify_revision_history
      source = @importer.source_raw_connection
      revisions = @maps.fetch(:post_revisions)
      reviewed =
        @plan
          .data
          .fetch("preserved_broken_revision_uploads", [])
          .index_by { |e| e.fetch("source_revision_id") }
      coder = PostRevision.type_for_attribute("modifications")
      excluded = GroupMapping.excluded(@plan.data.fetch("groups", []))
      ns = @plan.data.fetch("policy").fetch("namespace")
      refs = @importer.references(@plan)
      count = 0
      sql =
        Selection.new(@plan).sql(
          "post_revisions",
          PostRevision.column_names,
          "SELECT * FROM post_revisions",
        )
      SourceRows.each_batch(source, sql) do |rows|
        ids = rows.map { |r| revisions.fetch(r.fetch("id").to_i) }
        saved = PostRevision.where(id: ids).index_by(&:id)
        rows
          .zip(ids)
          .each do |row, dest|
            id = row.fetch("id").to_i
            revision = saved.fetch(dest)
            if (entry = reviewed[id])
              unless Digest::SHA256.hexdigest(row.fetch("modifications")) ==
                       entry.fetch("modifications_sha256")
                return false
              end
            end
            author = row["user_id"]&.to_i
            editor = @maps[:users].fetch(author, -1) if author
            expected =
              refs.revision(
                coder.deserialize(row["modifications"]),
                @maps,
                excluded_groups: excluded,
                namespace: ns,
                source_revision_id: id,
              )
            unless revision.modifications == expected &&
                     revision.post_id == @maps[:posts].fetch(row.fetch("post_id").to_i) &&
                     revision.user_id == (author && editor) &&
                     revision.number == row["number"]&.to_i &&
                     revision.hidden == (row["hidden"] == "t") &&
                     revision.unlisted == (row["unlisted"] == "t") &&
                     %w[created_at updated_at].all? { |key|
                       revision[key].to_r == Time.parse(row.fetch(key)).to_r
                     }
              return false
            end
            if author && !@maps[:users].key?(author)
              evidence =
                PostCustomField.where(
                  post_id: revision.post_id,
                  name: "#{ns}_original_revision_authors",
                ).pluck(:value)
              unless evidence.any? { |value|
                       JSON.parse(value).values_at("revision_id", "original_editor_id") ==
                         [dest, author]
                     }
                return false
              end
            end
          end
        count += rows.size
      end
      revisions.size == count && revisions.values.uniq.size == count &&
        (reviewed.keys - revisions.keys).empty?
    end

    def verify_reviewed_revisions(entries)
      coder = PostRevision.type_for_attribute("modifications")
      excluded = GroupMapping.excluded(@plan.data.fetch("groups", []))
      refs = @importer.references(@plan)
      entries.all? do |entry|
        id = entry.fetch("source_revision_id")
        source =
          @importer
            .source_raw_connection
            .exec_params(
              "SELECT post_id, number, created_at, modifications FROM post_revisions WHERE id=$1",
              [id],
            )
            .first
        unless source &&
                 Digest::SHA256.hexdigest(source.fetch("modifications")) ==
                   entry.fetch("modifications_sha256")
          next false
        end
        expected =
          refs.revision(
            coder.deserialize(source.fetch("modifications")),
            @maps,
            excluded_groups: excluded,
            namespace: @plan.data.fetch("policy").fetch("namespace"),
            source_revision_id: id,
          )
        saved =
          PostRevision.where(
            post_id: @maps.fetch(:posts).fetch(source.fetch("post_id").to_i),
            number: source.fetch("number"),
            created_at: source.fetch("created_at"),
          )
        saved.any? { |revision| revision.modifications == expected }
      end
    end

    def verify_staff_roles
      findings = @plan.data.fetch("source_findings")
      imported_staff = findings.fetch("new_staff_account_ids").to_set
      user_map = @maps.fetch(:users)
      check("reviewed_staff_accounts_imported") { imported_staff.subset?(user_map.keys.to_set) }
      matched_ids =
        findings.fetch("account_matches").to_set { |row| row.fetch("source_user_id").to_i }
      source_roles =
        findings
          .fetch("privileged_accounts")
          .to_h do |account|
            [
              account.fetch("id").to_i,
              [account.fetch("admin") == "t", account.fetch("moderator") == "t"],
            ]
          end
      admin_group, moderator_group, staff_group = Group::AUTO_GROUPS.values_at(*Group::STAFF_GROUPS)
      staff_groups = [admin_group, moderator_group, staff_group]
      user_map
        .select { |original, _| original.positive? && matched_ids.exclude?(original) }
        .each_slice(1000) do |pairs|
          ids = pairs.map(&:last)
          actual = User.unscoped.where(id: ids).pluck(:id, :admin, :moderator).index_by(&:first)
          memberships =
            GroupUser
              .where(user_id: ids, group_id: staff_groups)
              .pluck(:user_id, :group_id)
              .group_by(&:first)
          pairs.each do |original, id|
            admin, moderator =
              (
                if @plan.preserve_staff_roles?
                  source_roles.fetch(original, [false, false])
                else
                  [false, false]
                end
              )
            expected_groups = []
            expected_groups << admin_group if admin
            expected_groups << moderator_group if moderator
            expected_groups << staff_group if admin || moderator
            check("user_#{original}_staff_roles") do
              actual[id] == [id, admin, moderator] &&
                memberships.fetch(id, []).map(&:last).sort == expected_groups.sort
            end
          end
        end
    end

    def verify_groups
      @plan
        .data
        .fetch("groups", [])
        .each do |instruction|
          original = instruction.fetch("source_group_id")
          if instruction.fetch("action") == "exclude"
            check("group_#{original}_excluded") { !@maps[:groups].key?(original) }
            next
          end
          id = @maps[:groups].fetch(original)
          check("group_#{original}_mapping") do
            group = Group.find(id)
            !group.automatic && group.name == instruction.fetch("name") &&
              (
                instruction.fetch("action") != "reuse" ||
                  id == instruction.fetch("destination_group_id")
              )
          end
          expected =
            @importer
              .source_raw_connection
              .exec_params(
                "SELECT user_id FROM group_users WHERE group_id=$1 AND user_id>0",
                [original],
              )
              .filter_map { |row| @maps[:users][row.fetch("user_id").to_i] }
              .to_set
          actual = GroupUser.where(group_id: id).pluck(:user_id).to_set
          check("group_#{original}_memberships") { expected.subset?(actual) }
        end
    end

    def verify_access
      private_messages =
        @plan.topics.filter_map do |original, instruction|
          @maps[:topics].fetch(original) if instruction.fetch("action") == "copy_private_message"
        end
      {
        "topic_allowed_users" => ["user_id", :users],
        "topic_allowed_groups" => ["group_id", :groups],
      }.each do |table, (column, kind)|
        expected =
          @importer
            .source_raw_connection
            .exec(
              "SELECT a.topic_id,a.#{column} FROM #{table} a JOIN topics t ON t.id=a.topic_id WHERE t.archetype='private_message' AND t.id IN (#{@plan.sql_ids(@plan.included_ids)})",
            )
            .map do |row|
              [
                @maps[:topics].fetch(row.fetch("topic_id").to_i),
                @maps[kind].fetch(row.fetch(column).to_i),
              ]
            end
            .to_set
        actual =
          DB
            .query(
              "SELECT topic_id,#{column} AS participant FROM #{table} WHERE topic_id IN (:ids)",
              ids: private_messages,
            )
            .map { |r| [r.topic_id, r.participant] }
            .to_set
        check("#{table}_participants") { expected == actual }
      end
      @plan.topics.each do |original, instruction|
        next unless instruction.fetch("action") == "copy_private_message"
        topic = Topic.with_deleted.find(@maps[:topics].fetch(original))
        allowed_users = TopicAllowedUser.where(topic_id: topic.id).pluck(:user_id)
        allowed_groups = TopicAllowedGroup.where(topic_id: topic.id).pluck(:group_id)
        group_users = GroupUser.where(group_id: allowed_groups).pluck(:user_id)
        unrelated =
          User
            .where("id > 0")
            .where(admin: false, moderator: false)
            .where.not(id: allowed_users + group_users)
            .first
        check("private_message_#{original}_unrelated_access_denied") do
          !Guardian.new(unrelated).can_see?(topic)
        end
      end
    end

    def verify_group_access
      access = @plan.data.fetch("group_access", {})
      access
        .fetch("memberships", {})
        .each do |id, accounts|
          expected = accounts.map { |account| reviewed_user_id(account) }.to_set
          check("reused_group_#{id}_reviewed_membership") do
            GroupUser.where(group_id: id).where("user_id > 0").pluck(:user_id).to_set == expected
          end
        end
      access
        .fetch("expansions", [])
        .each_with_index do |change, index|
          readers = change.fetch("readers").map { |account| reviewed_user_id(account) }
          check("reviewed_access_expansion_#{index + 1}") do
            if change.fetch("type") == "category"
              category = Category.find(@keys.fetch(change.fetch("key")))
              category.read_restricted? &&
                GroupUser
                  .where(
                    group_id: CategoryGroup.where(category_id: category.id).select(:group_id),
                    user_id: readers,
                  )
                  .distinct
                  .count(:user_id) == readers.uniq.size
            elsif change["type"] == "category_moderation"
              groups =
                CategoryModerationGroup.where(category_id: @keys.fetch(change.fetch("key"))).select(
                  :group_id,
                )
              GroupUser.where(group_id: groups, user_id: readers).distinct.count(:user_id) ==
                readers.uniq.size
            else
              id = change.fetch("id")
              id = @maps.fetch(:topics).fetch(id) if change.fetch("side") == "source"
              topic = Topic.with_deleted.find(id)
              topic.private_message? &&
                topic.all_allowed_users.where(id: readers).count == readers.uniq.size
            end
          end
        end
    end

    def reviewed_user_id(account)
      side, id = account.split(":", 2)
      side == "source" ? @maps.fetch(:users).fetch(Integer(id)) : Integer(id)
    end

    def verify_prepared_media
      policy = @plan.data.fetch("upload_policy")
      reuse =
        policy
          .fetch("reuse")
          .to_h { |pair| pair.values_at("source_upload_id", "destination_upload_id") }
      preserve = policy["preserve_destination_uploads"]
      if preserve
        check("retained_media_ids") do
          policy.fetch("retained_ids").all? do |kind, ids|
            ids.all? { |source_id, dest_id| @maps.fetch(kind.to_sym)[Integer(source_id)] == dest_id }
          end
        end
      end
      PreuploadedMedia.open(@plan.data, @run_dir) do |media|
        (preserve ? %w[source] : %w[destination source]).each do |side|
          media.each_batch(side) do |batch|
            kind = batch.first[0]
            map = @maps.fetch(kind.to_sym)
            ids = batch.map { |_, id, _, _| side == "source" ? map.fetch(id) : id }
            model = kind == "uploads" ? Upload : OptimizedImage
            records = model.unscoped.where(id: ids).index_by(&:id)
            batch
              .zip(ids)
              .each do |(_, original, input, result), id|
                record = records.fetch(id)
                expected_result = result
                if !preserve && side == "source" && (kind == "optimized_images" || reuse.key?(original))
                  destination = media.destination_receipt(kind, id)
                  expected_result = destination if destination
                end
                attrs = media.attributes(kind, expected_result)
                unless attrs.all? { |key, value| record[key].to_s == value.to_s }
                  raise Error, "Wrong prepared storage metadata: #{side} #{kind} #{original}"
                end
                if kind == "uploads"
                  control = input["access_control_post_id"]&.to_i
                  control = @maps[:posts].fetch(control) if side == "source" && control
                  unless record.sha1 == input["sha1"] && record.secure? == result["secure"] &&
                           record.filesize == result["size"] &&
                           record.access_control_post_id == control
                    raise Error,
                          "Wrong prepared upload identity or permissions: #{side} #{original}"
                  end
                else
                  parent = input.fetch("upload_id").to_i
                  parent = @maps[:uploads].fetch(parent) if side == "source"
                  unless record.upload_id == parent &&
                           %w[width height extension].all? { |column|
                             record[column].to_s == input[column].to_s
                           }
                    raise Error, "Wrong prepared thumbnail parent or dimensions"
                  end
                end
              end
          end
        end
      end
      {
        uploads: "complete_upload_map",
        optimized_images: "complete_optimized_image_map",
      }.each do |table, name|
        check(name) do
          @importer
            .source_raw_connection
            .exec("SELECT id FROM #{table}")
            .column_values(0)
            .map(&:to_i)
            .to_set == @maps.fetch(table).keys.to_set
        end
      end
      check("prepared_upload_references") do
        sql = "SELECT target_id,upload_id FROM upload_references WHERE target_type='Post'"
        SourceRows.each_batch(@importer.source_raw_connection, sql) do |rows|
          expected =
            rows.filter_map do |row|
              post = @maps[:posts][row.fetch("target_id").to_i]
              [post, @maps[:uploads].fetch(row.fetch("upload_id").to_i)] if post
            end
          found =
            UploadReference
              .where(target_type: "Post", target_id: expected.map(&:first))
              .pluck(:target_id, :upload_id)
              .to_set
          unless expected.all? { |pair| found.include?(pair) }
            raise Error, "Missing prepared post attachment"
          end
        end
        true
      end
      check("no_local_upload_dependencies") do
        !Upload.where("id > 0 AND url ~ '^/[^/]'").exists? &&
          !OptimizedImage.where("url ~ '^/[^/]'").exists?
      end
      true
    end

    def verify_uploads
      expected =
        @importer.source_raw_connection.exec("SELECT id,sha1,url,filesize FROM uploads").to_a
      check("complete_upload_map") do
        expected.map { |r| r.fetch("id").to_i }.to_set == @maps[:uploads].keys.to_set
      end
      actual = Upload.unscoped.where(id: @maps[:uploads].values).index_by { |r| r.id }
      remote = @plan.data.dig("upload_policy", "mode") == "preserve_remote"
      expected.each do |row|
        original = row.fetch("id").to_i
        upload = actual.fetch(@maps[:uploads].fetch(original))
        if original > 0 && !remote
          source_file =
            Pathname.new(@plan.data.dig("upload_policy", "source_upload_root")).join(
              row.fetch("url").delete_prefix("/uploads/default/"),
            )
          destination_file = Rails.public_path.join(upload.url.delete_prefix("/"))
          check("upload_#{original}_bytes") do
            source_file.file? && destination_file.file? &&
              Digest::SHA256.file(source_file) == Digest::SHA256.file(destination_file)
          end
        end
        check("upload_#{original}_identity") do
          if original < 0
            upload.url == row["url"]
          else
            upload.sha1 == row["sha1"] && upload.filesize == row.fetch("filesize").to_i
          end
        end
        if remote
          check("upload_#{original}_remote_reference") do
            @importer.media_urls.fetch(row.fetch("url")) ==
              Media.remote_url(upload.url, @plan.data.dig("policy", "destination_url"))
          end
        end
      end
      verify_optimized_images if remote
    end

    def verify_optimized_images
      rows = @importer.source_raw_connection.exec("SELECT * FROM optimized_images ORDER BY id").to_a
      check("complete_optimized_image_map") do
        rows.map { |row| row.fetch("id").to_i }.to_set == @maps.fetch(:optimized_images).keys.to_set
      end
      rows.each do |row|
        image = OptimizedImage.find(@maps.fetch(:optimized_images).fetch(row.fetch("id").to_i))
        check("optimized_image_#{row.fetch("id")}_reference") do
          image.upload_id == @maps[:uploads].fetch(row.fetch("upload_id").to_i) &&
            %w[width height extension].all? do |column|
              image.public_send(column).to_s == row[column].to_s
            end &&
            @importer.media_urls.fetch(row.fetch("url")) ==
              Media.remote_url(image.url, @plan.data.dig("policy", "destination_url"))
        end
      end
    end

    def verify_solved
      {
        "DiscourseSolved::SolvedTopic" => :solved_topics,
        "DiscourseSolved::TopicAnswer" => :topic_answers,
        "DiscourseSolved::SharedIssue" => :shared_issues,
        "TopicTimer" => :topic_timers,
      }.each do |name, kind|
        klass = name.safe_constantize
        next unless klass
        expected_ids = []
        @importer
          .source_raw_connection
          .exec(
            "SELECT #{klass.column_names.map { |column| PG::Connection.quote_ident(column) }.join(",")} FROM #{klass.table_name}",
          )
          .each do |row|
            next if row["topic_id"] && !@maps[:topics].key?(row["topic_id"].to_i)
            if row["timerable_id"] &&
                 (row["type"] != "TopicTimer" || !@maps[:topics].key?(row["timerable_id"].to_i))
              next
            end
            if row["solved_topic_id"] &&
                 !@maps.fetch(:solved_topics).key?(row["solved_topic_id"].to_i)
              next
            end
            original = row.fetch("id").to_i
            expected_ids << original
            actual = klass.unscoped.find(@maps.fetch(kind).fetch(original))
            remaps = {
              "id" => kind,
              "topic_id" => :topics,
              "timerable_id" => :topics,
              "topic_timer_id" => :topic_timers,
              "solved_topic_id" => :solved_topics,
              "answer_post_id" => :posts,
              "accepter_user_id" => :users,
              "user_id" => :users,
              "deleted_by_id" => :users,
              "category_id" => :categories,
            }
            check("#{kind}_#{original}_associations_and_state") do
              row.all? do |column, value|
                value = @maps.fetch(remaps.fetch(column)).fetch(value.to_i) if value &&
                  remaps.key?(column)
                actual.public_send(column) == klass.type_for_attribute(column).cast(value)
              end
            end
          end
        check("complete_#{kind}_map") { expected_ids.to_set == @maps.fetch(kind).keys.to_set }
      end
    end

    def verify_likes
      expected =
        @importer
          .source_raw_connection
          .exec(
            "SELECT id,post_id,user_id,deleted_at FROM post_actions WHERE post_action_type_id=2 AND post_id IN (SELECT id FROM posts WHERE topic_id IN (#{@plan.sql_ids(@plan.included_ids)}))",
          )
          .to_a
      expected.each do |row|
        check("like_#{row.fetch("id")}_preserved") do
          like =
            PostAction.with_deleted.find_by(
              id: @maps.fetch(:post_actions).fetch(row.fetch("id").to_i),
              post_id: @maps[:posts].fetch(row.fetch("post_id").to_i),
              user_id: @maps[:users].fetch(row.fetch("user_id").to_i),
              post_action_type_id: 2,
            )
          like && like.deleted_at&.to_r == (Time.parse(row["deleted_at"]).to_r if row["deleted_at"])
        end
      end
    end
  end
end

module BulkImport::DiscourseMerge
  class VerificationContext
    attr_reader :account_outcomes,
                :matched_summaries,
                :maps,
                :category_keys,
                :source_raw_connection,
                :media_urls,
                :content_ids

    def initialize(connection, ledger)
      unless ledger.fetch("stage") == "complete"
        raise Error, "Verification requires a complete ledger"
      end
      @account_outcomes = ledger["account_outcomes"]
      @matched_summaries = ledger.fetch("matched_summaries", {})
      @source_raw_connection = connection
      @category_keys = ledger.fetch("category_keys")
      @content_ids =
        ledger
          .fetch("content_ids", {})
          .slice(*ContentPolicy::TABLES)
          .transform_values { |ids| ids.to_h { |id, target| [Integer(id), Integer(target)] } }
      @media_urls = ledger.fetch("media_urls", {})
      @username_changes = ledger.fetch("username_changes", {})
      @group_changes = ledger.fetch("group_changes", {})
      @maps =
        %w[
          users
          groups
          categories
          topics
          posts
          uploads
          optimized_images
          topic_timers
          solved_topics
          topic_answers
          shared_issues
          post_actions
        ].to_h do |name|
          values = ledger.fetch(name)
          raise Error, "Invalid ledger mapping #{name}" unless values.is_a?(Hash)
          [
            name.to_sym,
            values.to_h do |source, destination|
              mapped = destination.nil? && name == "categories" ? nil : Integer(destination)
              [Integer(source), mapped]
            end,
          ]
        end
      if ledger.key?("post_revisions")
        @maps[:post_revisions] = ledger
          .fetch("post_revisions")
          .to_h { |id, target| [Integer(id), Integer(target)] }
      end
      @maps[:tags] = ledger
        .fetch("tags")
        .to_h { |id, target| [Integer(id), Integer(target)] } if ledger.key?("tags")
    end

    def references(plan)
      @references ||=
        References.from_plan(
          plan,
          @maps,
          source_connection: source_raw_connection,
          usernames: @username_changes,
          group_names: @group_changes,
          media_urls: @media_urls,
        )
    end
  end
end
