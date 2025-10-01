# frozen_string_literal: true

RSpec.describe "Managing Posts solved status" do
  let(:topic) { Fabricate(:topic_with_op) }
  fab!(:user) { Fabricate(:trust_level_4) }
  let(:p1) { Fabricate(:post, topic: topic) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe "custom filters" do
    before do
      SiteSetting.allow_solved_on_all_topics = false
      SiteSetting.enable_solved_tags = solvable_tag.name
    end

    fab!(:solvable_category) do
      category = Fabricate(:category)

      CategoryCustomField.create(
        category_id: category.id,
        name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
        value: "true",
      )

      category
    end

    fab!(:solvable_tag) { Fabricate(:tag) }

    fab!(:solved_in_category) do
      topic = Fabricate(:topic, category: solvable_category)
      Fabricate(:solved_topic, topic:, answer_post: Fabricate(:post, topic:))
      topic
    end

    fab!(:solved_in_tag) do
      topic = Fabricate(:topic, tags: [solvable_tag])
      Fabricate(:solved_topic, topic:, answer_post: Fabricate(:post, topic:))
      topic
    end

    fab!(:solved_pm) do
      topic = Fabricate(:topic, archetype: Archetype.private_message, category_id: nil)
      Fabricate(:solved_topic, topic:, answer_post: Fabricate(:post, topic:))
      topic
    end

    fab!(:unsolved_in_category) { Fabricate(:topic, category: solvable_category) }
    fab!(:unsolved_in_tag) { Fabricate(:topic, tags: [solvable_tag]) }

    fab!(:unsolved_topic) { Fabricate(:topic) }

    it "can filter by solved status" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_from_query_string("status:solved")
          .pluck(:id),
      ).to contain_exactly(solved_in_category.id, solved_in_tag.id)
    end

    it "can filter by unsolved status" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_from_query_string("status:unsolved")
          .pluck(:id),
      ).to contain_exactly(unsolved_in_category.id, unsolved_in_tag.id)
    end

    describe "topics_filter_options modifier" do
      it "adds solved and unsolved filter options when plugin is enabled" do
        options = TopicsFilter.option_info(Guardian.new)

        solved_option = options.find { |o| o[:name] == "status:solved" }
        unsolved_option = options.find { |o| o[:name] == "status:unsolved" }

        expect(solved_option).to be_present
        expect(solved_option).to include(
          name: "status:solved",
          description: I18n.t("solved.filter.description.solved"),
          type: "text",
        )

        expect(unsolved_option).to be_present
        expect(unsolved_option).to include(
          name: "status:unsolved",
          description: I18n.t("solved.filter.description.unsolved"),
          type: "text",
        )
      end

      it "does not add filter options when plugin is disabled" do
        SiteSetting.solved_enabled = false

        guardian = Guardian.new
        options = TopicsFilter.option_info(guardian)

        solved_option = options.find { |o| o[:name] == "status:solved" }
        unsolved_option = options.find { |o| o[:name] == "status:unsolved" }

        expect(solved_option).to be_nil
        expect(unsolved_option).to be_nil
      end
    end
  end

  describe "search" do
    before { SearchIndexer.enable }

    after { SearchIndexer.disable }

    it "can prioritize solved topics in search" do
      normal_post =
        Fabricate(
          :post,
          raw: "My reply carrot",
          topic: Fabricate(:topic, title: "A topic that is not solved but open"),
        )

      solved_post =
        Fabricate(
          :post,
          raw: "My solution carrot",
          topic: Fabricate(:topic, title: "A topic that will be closed", closed: true),
        )

      DiscourseSolved.accept_answer!(solved_post, Discourse.system_user)

      result = Search.execute("carrot")
      expect(result.posts.pluck(:id)).to eq([normal_post.id, solved_post.id])

      SiteSetting.prioritize_solved_topics_in_search = true

      result = Search.execute("carrot")
      expect(result.posts.pluck(:id)).to eq([solved_post.id, normal_post.id])
    end

    describe "#advanced_search" do
      fab!(:category_enabled) do
        category = Fabricate(:category)
        category_custom_field =
          CategoryCustomField.new(
            category_id: category.id,
            name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
            value: "true",
          )
        category_custom_field.save
        category
      end
      fab!(:category_disabled) do
        category = Fabricate(:category)
        category_custom_field =
          CategoryCustomField.new(
            category_id: category.id,
            name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
            value: "false",
          )
        category_custom_field.save
        category
      end
      fab!(:tag)
      fab!(:topic_unsolved) { Fabricate(:topic, user:, category: category_enabled) }
      fab!(:topic_unsolved_2) { Fabricate(:topic, user: user, tags: [tag]) }
      fab!(:topic_solved) do
        topic = Fabricate(:topic, category: category_enabled)
        Fabricate(:solved_topic, topic:, answer_post: Fabricate(:post, topic:))
        topic
      end
      fab!(:topic_disabled_1) { Fabricate(:topic, category: category_disabled) }
      fab!(:topic_disabled_2) { Fabricate(:topic, category: category_disabled) }
      fab!(:post_unsolved) { Fabricate(:post, topic: topic_unsolved) }
      fab!(:post_unsolved_2) { Fabricate(:post, topic: topic_unsolved_2) }
      fab!(:post_solved) do
        post = Fabricate(:post, topic: topic_solved)
        DiscourseSolved.accept_answer!(post, Discourse.system_user)
        post
      end
      fab!(:post_disabled_1) { Fabricate(:post, topic: topic_disabled_1) }
      fab!(:post_disabled_2) { Fabricate(:post, topic: topic_disabled_2) }

      before do
        SiteSetting.enable_solved_tags = tag.name
        SearchIndexer.enable
        Jobs.run_immediately!

        SearchIndexer.index(topic_unsolved, force: true)
        SearchIndexer.index(topic_unsolved_2, force: true)
        SearchIndexer.index(topic_solved, force: true)
        SearchIndexer.index(topic_disabled_1, force: true)
        SearchIndexer.index(topic_disabled_2, force: true)
      end

      after { SearchIndexer.disable }

      describe "searches for unsolved topics" do
        describe "when allow solved on all topics is disabled" do
          before { SiteSetting.allow_solved_on_all_topics = false }

          it "only returns unsolved posts from categories and tags where solving is enabled" do
            result = Search.execute("status:unsolved")
            expect(result.posts.pluck(:id)).to match_array([post_unsolved.id, post_unsolved_2.id])
          end

          it "returns the filtered results when combining search with a tag" do
            result = Search.execute("status:unsolved tag:#{tag.name}")
            expect(result.posts.pluck(:id)).to match_array([post_unsolved_2.id])
          end
        end

        describe "when allow solved on all topics is enabled" do
          before { SiteSetting.allow_solved_on_all_topics = true }
          it "only returns posts where the post is not solved" do
            result = Search.execute("status:unsolved")
            expect(result.posts.pluck(:id)).to match_array(
              [post_unsolved.id, post_unsolved_2.id, post_disabled_1.id, post_disabled_2.id],
            )
          end
        end
      end
    end
  end

  describe "auto bump" do
    it "does not automatically bump solved topics" do
      category = Fabricate(:category_with_definition)

      post = create_post(category: category)
      post2 = create_post(category: category)

      DiscourseSolved.accept_answer!(post, Discourse.system_user)

      category.num_auto_bump_daily = 2
      category.save!

      freeze_time 1.month.from_now

      expect(category.auto_bump_topic!).to eq(true)

      freeze_time 13.hours.from_now

      expect(category.auto_bump_topic!).to eq(false)

      expect(post.topic.reload.posts_count).to eq(1)
      expect(post2.topic.reload.posts_count).to eq(2)
    end
  end

  describe "accepting a post as the answer" do
    before do
      sign_in(user)
      SiteSetting.solved_topics_auto_close_hours = 2
    end

    it "can mark a post as the accepted answer correctly" do
      freeze_time

      post "/solution/accept.json", params: { id: p1.id }

      expect(response.status).to eq(200)
      expect(topic.solved.answer_post_id).to eq(p1.id)

      topic.reload

      expect(topic.public_topic_timer.status_type).to eq(TopicTimer.types[:silent_close])

      expect(topic.solved.topic_timer).to eq(topic.public_topic_timer)
      expect(topic.public_topic_timer.execute_at).to eq_time(Time.zone.now + 2.hours)
      expect(topic.public_topic_timer.based_on_last_post).to eq(true)
    end

    it "gives priority to category's solved_topics_auto_close_hours setting" do
      freeze_time
      custom_auto_close_category = Fabricate(:category)
      topic_2 = Fabricate(:topic_with_op, category: custom_auto_close_category)
      post_2 = Fabricate(:post, topic: topic_2)
      custom_auto_close_category.custom_fields["solved_topics_auto_close_hours"] = 4
      custom_auto_close_category.save_custom_fields

      post "/solution/accept.json", params: { id: post_2.id }

      expect(response.status).to eq(200)
      expect(topic_2.solved.answer_post_id).to eq(post_2.id)

      topic_2.reload

      expect(topic_2.public_topic_timer.status_type).to eq(TopicTimer.types[:silent_close])

      expect(topic_2.solved.topic_timer).to eq(topic_2.public_topic_timer)
      expect(topic_2.public_topic_timer.execute_at).to eq_time(Time.zone.now + 4.hours)
      expect(topic_2.public_topic_timer.based_on_last_post).to eq(true)
    end

    it "sends notifications to correct users" do
      SiteSetting.notify_on_staff_accept_solved = true
      user = Fabricate(:user)
      topic = Fabricate(:topic, user: user)
      post = Fabricate(:post, post_number: 2, topic: topic)

      op = topic.user
      user = post.user

      expect { DiscourseSolved.accept_answer!(post, Discourse.system_user) }.to change {
        user.notifications.count
      }.by(1) & change { op.notifications.count }.by(1)

      notification = user.notifications.last
      expect(notification.notification_type).to eq(Notification.types[:custom])
      expect(notification.topic_id).to eq(post.topic_id)
      expect(notification.post_number).to eq(post.post_number)

      notification = op.notifications.last
      expect(notification.notification_type).to eq(Notification.types[:custom])
      expect(notification.topic_id).to eq(post.topic_id)
      expect(notification.post_number).to eq(post.post_number)
    end

    it "does not set a timer when the topic is closed" do
      topic.update!(closed: true)
      post "/solution/accept.json", params: { id: p1.id }

      expect(response.status).to eq(200)

      p1.reload
      topic.reload

      expect(topic.solved.answer_post_id).to eq(p1.id)
      expect(topic.public_topic_timer).to eq(nil)
      expect(topic.closed).to eq(true)
    end

    it "works with staff and trashed topics" do
      topic.trash!(Discourse.system_user)

      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(403)

      sign_in(Fabricate(:admin))
      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(200)

      p1.reload
      expect(topic.solved.answer_post_id).to eq(p1.id)
    end

    it "removes the solution when the post is deleted" do
      reply = Fabricate(:post, post_number: 2, topic: topic)

      post "/solution/accept.json", params: { id: reply.id }
      expect(response.status).to eq(200)

      expect(topic.solved.answer_post_id).to eq(reply.id)

      PostDestroyer.new(Discourse.system_user, reply, context: "spec").destroy
      reply.topic.reload

      expect(topic.solved).to be(nil)
    end

    it "does not allow you to accept a whisper" do
      whisper = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      sign_in(Fabricate(:admin))

      post "/solution/accept.json", params: { id: whisper.id }
      expect(response.status).to eq(403)
    end

    it "triggers a webhook" do
      Fabricate(:solved_web_hook)
      post "/solution/accept.json", params: { id: p1.id }

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("accepted_solution")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(p1.id)
    end
  end

  describe "#unaccept" do
    before { sign_in(user) }

    describe "when solved_topics_auto_close_hours is enabled" do
      before do
        SiteSetting.solved_topics_auto_close_hours = 2
        DiscourseSolved.accept_answer!(p1, user)
        topic.reload
      end

      it "should unmark the post as solved" do
        expect do post "/solution/unaccept.json", params: { id: p1.id } end.to change {
          topic.reload.public_topic_timer
        }.to(nil)

        expect(response.status).to eq(200)
        p1.reload

        expect(topic.solved).to be(nil)
      end
    end

    it "triggers a webhook" do
      DiscourseSolved.accept_answer!(p1, user)

      Fabricate(:solved_web_hook)
      post "/solution/unaccept.json", params: { id: p1.id }

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("unaccepted_solution")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(p1.id)
    end
  end

  context "with group moderators" do
    fab!(:group_user)
    let!(:category_moderation_group) do
      Fabricate(:category_moderation_group, category: p1.topic.category, group: group_user.group)
    end
    let(:user_gm) { group_user.user }

    before do
      SiteSetting.enable_category_group_moderation = true
      sign_in(user_gm)
    end

    it "can accept a solution" do
      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(200)
    end
  end

  context "with discourse-assign installed", if: defined?(DiscourseAssign) do
    let(:admin) { Fabricate(:admin) }
    fab!(:group)
    before do
      SiteSetting.solved_enabled = true
      SiteSetting.assign_enabled = true
      SiteSetting.enable_assign_status = true
      SiteSetting.assign_allowed_on_groups = "#{group.id}"
      SiteSetting.assigns_public = true
      SiteSetting.assignment_status_on_solve = "Done"
      SiteSetting.assignment_status_on_unsolve = "New"
      SiteSetting.ignore_solved_topics_in_assigned_reminder = false
      group.add(p1.acting_user)
      group.add(user)

      sign_in(user)
    end

    describe "updating assignment status on solve when assignment_status_on_solve is set" do
      it "update all assignments to this status when a post is accepted" do
        assigner = Assigner.new(p1.topic, user)
        result = assigner.assign(user)
        expect(result[:success]).to eq(true)

        expect(p1.topic.assignment.status).to eq("New")
        DiscourseSolved.accept_answer!(p1, user)
        topic.reload

        expect(topic.solved.answer_post_id).to eq(p1.id)
        expect(p1.topic.assignment.reload.status).to eq("Done")
      end

      it "update all assignments to this status when a post is unaccepted" do
        assigner = Assigner.new(p1.topic, user)
        result = assigner.assign(user)
        expect(result[:success]).to eq(true)

        DiscourseSolved.accept_answer!(p1, user)

        expect(p1.reload.topic.assignment.reload.status).to eq("Done")

        DiscourseSolved.unaccept_answer!(p1)

        expect(p1.reload.topic.assignment.reload.status).to eq("New")
      end

      it "does not update the assignee when a post is accepted" do
        user = Fabricate(:user)
        user_2 = Fabricate(:user)
        user_3 = Fabricate(:user)
        group.add(user)
        group.add(user_2)
        group.add(user_3)

        topic_question = Fabricate(:topic, user: user)

        Fabricate(:post, topic: topic_question, user: user)
        Fabricate(:post, topic: topic_question, user: user_2)

        result = Assigner.new(topic_question, user_2).assign(user_2)
        expect(result[:success]).to eq(true)

        post_response = Fabricate(:post, topic: topic_question, user: user_3)
        Assigner.new(post_response, user_3).assign(user_3)

        DiscourseSolved.accept_answer!(post_response, user)

        expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
        expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
        DiscourseSolved.unaccept_answer!(post_response)

        expect(topic_question.assignment.assigned_to_id).to eq(user_2.id)
        expect(post_response.assignment.assigned_to_id).to eq(user_3.id)
      end

      describe "assigned topic reminder" do
        it "excludes solved topics when ignore_solved_topics_in_assigned_reminder is false" do
          other_topic = Fabricate(:topic, title: "Topic that should be there")
          post = Fabricate(:post, topic: other_topic, user: user)

          other_topic2 = Fabricate(:topic, title: "Topic that should be there2")
          post2 = Fabricate(:post, topic: other_topic2, user: user)

          Assigner.new(post.topic, user).assign(user)
          Assigner.new(post2.topic, user).assign(user)

          reminder = PendingAssignsReminder.new
          topics = reminder.send(:assigned_topics, user, order: :asc)
          expect(topics.to_a.length).to eq(2)

          DiscourseSolved.accept_answer!(post2, Discourse.system_user)
          topics = reminder.send(:assigned_topics, user, order: :asc)
          expect(topics.to_a.length).to eq(2)
          expect(topics).to include(other_topic2)

          SiteSetting.ignore_solved_topics_in_assigned_reminder = true
          topics = reminder.send(:assigned_topics, user, order: :asc)
          expect(topics.to_a.length).to eq(1)
          expect(topics).not_to include(other_topic2)
          expect(topics).to include(other_topic)
        end
      end

      describe "assigned count for user" do
        it "does not count solved topics using assignment_status_on_solve status" do
          SiteSetting.ignore_solved_topics_in_assigned_reminder = true

          other_topic = Fabricate(:topic, title: "Topic that should be there")
          post = Fabricate(:post, topic: other_topic, user: user)

          other_topic2 = Fabricate(:topic, title: "Topic that should be there2")
          post2 = Fabricate(:post, topic: other_topic2, user: user)

          Assigner.new(post.topic, user).assign(user)
          Assigner.new(post2.topic, user).assign(user)

          reminder = PendingAssignsReminder.new
          expect(reminder.send(:assigned_count_for, user)).to eq(2)

          DiscourseSolved.accept_answer!(post2, Discourse.system_user)
          expect(reminder.send(:assigned_count_for, user)).to eq(1)
        end
      end
    end
  end

  describe "#unaccept_answer!" do
    it "works even when the topic has been deleted" do
      user = Fabricate(:user, trust_level: 1)
      topic = Fabricate(:topic, user:)
      reply = Fabricate(:post, topic:, user:, post_number: 2)

      DiscourseSolved.accept_answer!(reply, user)

      topic.trash!(Discourse.system_user)
      reply.reload

      expect(reply.topic).to eq(nil)

      expect { DiscourseSolved.unaccept_answer!(reply) }.not_to raise_error
    end
  end

  describe "#accept_answer!" do
    it "marks the post as the accepted answer correctly" do
      user = Fabricate(:user, trust_level: 1)
      topic = Fabricate(:topic, user:)
      reply1 = Fabricate(:post, topic:, user:, post_number: 2)
      reply2 = Fabricate(:post, topic:, user:, post_number: 3)

      DiscourseSolved.accept_answer!(reply1, user)
      topic.reload

      expect(topic.solved.answer_post_id).to eq(reply1.id)
      expect(topic.solved.topic_timer).to eq(topic.public_topic_timer)

      DiscourseSolved.accept_answer!(reply2, user)
      topic.reload

      expect(topic.solved.answer_post_id).to eq(reply2.id)
    end
  end

  describe "user actions stream modifier" do
    it "correctly list solutions" do
      t1 = Fabricate(:topic)
      t2 = Fabricate(:topic)
      t3 = Fabricate(:topic)

      p1 = Fabricate(:post, topic: t1, user:)
      p2 = Fabricate(:post, topic: t2, user:)
      p3 = Fabricate(:post, topic: t3, user:)

      DiscourseSolved.accept_answer!(p1, Discourse.system_user)
      DiscourseSolved.accept_answer!(p2, Discourse.system_user)
      DiscourseSolved.accept_answer!(p3, Discourse.system_user)

      t1.trash!(Discourse.system_user)
      t2.convert_to_private_message(Discourse.system_user)

      expect(
        UserAction.stream(
          user_id: user.id,
          action_types: [::UserAction::SOLVED],
          guardian: user.guardian,
        ).map(&:post_id),
      ).to contain_exactly p3.id
    end
  end

  describe "publishing messages" do
    fab!(:private_user, :user)
    fab!(:admin)

    before do
      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      SiteSetting.show_who_marked_solved = true
    end

    it "publishes MessageBus messages" do
      topic = Fabricate(:topic, user:)
      reply = Fabricate(:post, topic:, user:, post_number: 2)

      messages =
        MessageBus.track_publish("/topic/#{reply.topic.id}") do
          DiscourseSolved.accept_answer!(reply, admin)
          DiscourseSolved.unaccept_answer!(reply)
        end
      expect(messages.count).to eq(2)
      expect(messages.map(&:data).map { |m| m[:type] }.uniq).to match_array(
        %i[accepted_solution unaccepted_solution],
      )

      accepted_message = messages.find { |m| m.data[:type] == :accepted_solution }
      expect(accepted_message.data[:accepted_answer][:post_number]).to eq(2)
      expect(accepted_message.data[:accepted_answer][:username]).to eq(user.username)
      expect(accepted_message.data[:accepted_answer][:name]).to eq(user.name)
      expect(accepted_message.data[:accepted_answer][:excerpt]).to eq(reply.excerpt)
      expect(accepted_message.data[:accepted_answer][:accepter_name]).to eq(admin.name)
      expect(accepted_message.data[:accepted_answer][:accepter_username]).to eq(admin.username)

      unaccepted_message = messages.find { |m| m.data[:type] == :unaccepted_solution }
      expect(unaccepted_message.data[:accepted_answer]).to eq(nil)
    end

    it "publishes MessageBus messages securely for PMs" do
      private_topic = Fabricate(:private_message_topic, user: private_user, recipient: admin)
      private_post = Fabricate(:post, topic: private_topic)
      reply = Fabricate(:post, topic: private_topic, user:, post_number: 2)

      messages =
        MessageBus.track_publish("/topic/#{private_post.topic.id}") do
          DiscourseSolved.accept_answer!(reply, admin)
        end

      expect(messages.count).to eq(1)

      authorized_user_messages = messages.find { |m| m.user_ids.include?(private_user.id) }
      expect(authorized_user_messages.data[:type]).to eq(:accepted_solution)

      unauthorized_user_messages = messages.find { |m| m.user_ids.include?(user.id) }
      expect(unauthorized_user_messages).to eq(nil)
    end

    it "publishes MessageBus messages securely for secure categories" do
      group = Fabricate(:group).tap { |g| g.add(private_user) }
      other_group = Fabricate(:group).tap { |g| g.add(user) }
      private_category = Fabricate(:private_category, group: group)
      private_topic = Fabricate(:topic, category: private_category)
      private_post = Fabricate(:post, topic: private_topic)
      private_reply = Fabricate(:post, topic: private_topic, post_number: 2)

      messages =
        MessageBus.track_publish("/topic/#{private_post.topic.id}") do
          DiscourseSolved.accept_answer!(private_reply, admin)
        end

      expect(messages.count).to eq(1)

      authorized_user_messages = messages.find { |m| m.group_ids.include?(group.id) }
      expect(authorized_user_messages.data[:type]).to eq(:accepted_solution)

      unauthorized_user_messages = messages.find { |m| m.group_ids.include?(other_group.id) }
      expect(unauthorized_user_messages).to eq(nil)
    end
  end
end
