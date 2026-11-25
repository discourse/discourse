# frozen_string_literal: true

require_relative "write_support"

# Each variant is calibrated against its own unrestricted baseline.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with MCP content write rules"

  include UploadsHelpers

  let(:unsafe_raw) do
    "Please read [this existing discussion](/t/garden/#{McpContentWriteHelpers::MISSING_ID}) before replying."
  end

  def reviewable_arguments(reviewable, action)
    { reviewable_id: reviewable.id, action_id: action, confirm: true }
  end

  def assert_stored_refusal(name, args, access_token: token)
    before_state = content_state
    jobs = Jobs::ProcessPost.jobs.deep_dup
    response = rpc(name, args, access_token: access_token)
    aggregate_failures do
      expect_reference_refusal(response)
      expect(content_state).to eq(before_state), "STORED RAW: refusal changed persisted content"
      expect(Jobs::ProcessPost.jobs).to eq(jobs), "STORED RAW: refusal scheduled processing"
    end
  end

  it "calibrates no-rule processing, mention recooking and upload-security queues outside savepoints" do
    expect_success(
      rpc(
        "discourse_update_topic",
        { topic_id: post.topic_id, title: "A revised seasonal garden discussion" },
      ),
    )
    expect_job_enqueued(job: :process_post, args: { post_id: post.id })

    group =
      Fabricate(:group, name: "u4queuewriters", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    mention =
      PostCreator.create!(
        admin,
        topic_id: post.topic_id,
        raw: "Please ask @#{group.name} about our seasonal garden plans.",
      )
    expect_success(rpc("discourse_update_group", { group_id: group.id, name: "u4queuechanged" }))
    expect_job_enqueued(
      job: :update_group_mentions,
      args: {
        group_id: group.id,
        previous_name: "u4queuewriters",
      },
    )
    Jobs::UpdateGroupMentions.new.execute(group_id: group.id, previous_name: "u4queuewriters")
    expect(mention.reload.raw).to include("@u4queuechanged")

    destination = Fabricate(:category)
    expect_success(
      rpc("discourse_update_topic", { topic_id: post.topic_id, category_id: destination.id }),
    )
    expect_job_enqueued(job: :update_topic_upload_security, args: { topic_id: post.topic_id })
  end

  it "checks UpdateTopic's existing first-post raw before a safe title-only update" do
    post.update!(raw: unsafe_raw)
    args = { topic_id: post.topic_id, title: "A revised seasonal garden discussion" }
    isolated do
      expect_success(rpc("discourse_update_topic", args))
      expect(post.topic.reload.title).to eq(args[:title])
    end
    activate!
    assert_stored_refusal("discourse_update_topic", args)
  end

  %w[approve_post revise_and_reject_post].each do |action|
    it "checks queued payload raw before #{action} even with no agent text" do
      reviewable =
        Fabricate(
          :reviewable_queued_post_topic,
          category: allowed_category,
          target_created_by: recipient,
          payload: {
            raw: unsafe_raw,
            title: "Seasonal queued garden observations",
            tags: [],
            archetype: "regular",
          },
        )
      args = reviewable_arguments(reviewable, action)
      isolated do
        expect_success(rpc("discourse_perform_reviewable_action", args))
        expect(reviewable.reload.status).not_to eq(Reviewable.statuses[:pending])
        expect(Post.where("raw LIKE ?", "%#{unsafe_raw}%").exists?).to eq(true)
      end
      activate!
      assert_stored_refusal("discourse_perform_reviewable_action", args)
    end
  end

  it "validates definition-post raw during category description updates" do
    category = Fabricate(:category_with_definition, user: admin)
    args = { category_id: category.id, description: unsafe_raw }
    isolated do
      expect_success(rpc("discourse_update_category", args))
      expect(category.topic.first_post.reload.raw).to eq(unsafe_raw)
    end
    activate!
    assert_stored_refusal("discourse_update_category", args)
  end

  it "refuses recovery of a deleted post whose stored raw contains a reference" do
    reply = Fabricate(:post, user: admin, topic: post.topic, raw: unsafe_raw)
    PostDestroyer.new(admin, reply).destroy
    expect(reply.reload.deleted_at).to be_present
    args = { post_id: reply.id, deleted: false }
    isolated do
      expect_success(rpc("discourse_post_set_deleted", args))
      expect(reply.reload.deleted_at).to be_nil
    end
    activate!
    assert_stored_refusal("discourse_post_set_deleted", args)
  end

  it "checks historical deletion-revision raw on user recovery rather than the safe deletion placeholder" do
    author = Fabricate(:user, trust_level: TrustLevel[2])
    author_token = issue_token(author)
    reply = Fabricate(:post, user: author, topic: post.topic, raw: unsafe_raw)
    PostDestroyer.new(author, reply).destroy
    reply.reload
    expect(reply.user_deleted).to eq(true)
    expect(reply.raw).not_to eq(unsafe_raw)
    expect(reply.revisions.last.modifications.fetch("raw").first).to eq(unsafe_raw)
    args = { post_id: reply.id, deleted: false }
    isolated do
      expect_success(rpc("discourse_post_set_deleted", args, access_token: author_token))
      expect(reply.reload.raw).to eq(unsafe_raw)
      expect(reply.user_deleted).to eq(false)
    end
    activate!
    assert_stored_refusal("discourse_post_set_deleted", args, access_token: author_token)
  end

  it "checks hidden post raw before reviewable approval unhides it" do
    reply = Fabricate(:post, user: recipient, topic: post.topic, raw: unsafe_raw, hidden: true)
    reviewable = ReviewablePost.queue_for_review(reply)
    args = reviewable_arguments(reviewable, "approve_and_unhide")
    isolated do
      expect_success(rpc("discourse_perform_reviewable_action", args))
      expect(reply.reload.hidden).to eq(false)
    end
    activate!
    assert_stored_refusal("discourse_perform_reviewable_action", args)
  end

  it "checks stored raw before a flagged reviewable disagreement unhides it" do
    reply = Fabricate(:post, user: recipient, topic: post.topic, raw: unsafe_raw)
    flagger = Fabricate(:user, trust_level: TrustLevel[2])
    reviewable = PostActionCreator.off_topic(flagger, reply).reviewable
    reply.update!(hidden: true)
    args = reviewable_arguments(reviewable, "disagree_and_restore")
    isolated do
      expect_success(rpc("discourse_perform_reviewable_action", args))
      expect(reply.reload.hidden).to eq(false)
    end
    activate!
    assert_stored_refusal("discourse_perform_reviewable_action", args)
  end

  it "checks stored raw before reviewable approval restores a deleted post" do
    reply = Fabricate(:post, user: recipient, topic: post.topic, raw: unsafe_raw)
    reviewable = ReviewablePost.queue_for_review(reply)
    PostDestroyer.new(admin, reply).destroy
    args = reviewable_arguments(reviewable, "approve_and_restore")
    isolated do
      expect_success(rpc("discourse_perform_reviewable_action", args))
      expect(reply.reload.deleted_at).to be_nil
    end
    activate!
    assert_stored_refusal("discourse_perform_reviewable_action", args)
  end

  it "checks unchanged group bio_raw on an unrelated full_name save" do
    group = Fabricate(:group, bio_raw: unsafe_raw)
    args = { group_id: group.id, full_name: "Seasonal garden writers" }
    isolated do
      expect_success(rpc("discourse_update_group", args))
      expect(group.reload.full_name).to eq(args[:full_name])
      expect(group.bio_cooked).to include("/t/garden/")
    end
    activate!
    assert_stored_refusal("discourse_update_group", args)
  end

  it "refuses group renaming that would rewrite and recook other mention posts" do
    group =
      Fabricate(:group, name: "u4mentionwriters", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    mention =
      PostCreator.create!(
        admin,
        topic_id: post.topic_id,
        raw: "These observations are for @#{group.name} to consider.",
      )
    expect(mention.cooked).to include('class="mention-group')
    args = { group_id: group.id, name: "u4renamedwriters" }
    isolated do
      expect_success(rpc("discourse_update_group", args))
      Jobs::UpdateGroupMentions.new.execute(group_id: group.id, previous_name: "u4mentionwriters")
      expect(mention.reload.raw).to include("@#{args[:name]}")
    end
    activate!
    before_state = content_state
    jobs = Jobs::UpdateGroupMentions.jobs.deep_dup
    response = rpc("discourse_update_group", args)
    aggregate_failures do
      expect_refusal(response)
      expect(content_state).to eq(before_state), "GROUP COPY: rename changed group or mention posts"
      expect(Jobs::UpdateGroupMentions.jobs).to eq(jobs),
      "GROUP COPY: rename scheduled mention recooking"
    end
  end

  it "refuses topic category changes that schedule upload-security rebakes of other posts" do
    setup_s3
    SiteSetting.secure_uploads = true
    destination = Fabricate(:private_category, group: Fabricate(:group))
    upload = Fabricate(:upload_s3, user: admin, secure: false)
    stub_upload(upload)
    reply =
      Fabricate(
        :post,
        user: admin,
        topic: post.topic,
        raw: "An illustration of our gardens.\n\n![Garden](#{upload.short_url})",
      )
    reply.link_post_uploads
    upload.update!(access_control_post: reply)
    reply.update_columns(baked_at: 2.days.ago, baked_version: 0)
    expect(UploadReference.exists?(upload: upload, target: reply)).to eq(true)
    args = { topic_id: post.topic_id, category_id: destination.id }
    isolated do
      expect_success(rpc("discourse_update_topic", args))
      expect(post.topic.reload.category_id).to eq(destination.id)
      Jobs::UpdateTopicUploadSecurity.new.execute(topic_id: post.topic_id)
      expect(upload.reload.secure?).to eq(true)
      expect(reply.reload.baked_version).to eq(Post::BAKED_VERSION)
      expect(reply.cooked).to include("/secure-uploads/")
    end
    activate!
    before_state = content_state
    jobs = Jobs::UpdateTopicUploadSecurity.jobs.deep_dup
    response = rpc("discourse_update_topic", args)
    aggregate_failures do
      expect_refusal(response)
      expect(content_state).to eq(before_state), "CATEGORY COPY: move persisted"
      expect(Jobs::UpdateTopicUploadSecurity.jobs).to eq(jobs),
      "CATEGORY COPY: move scheduled upload-security rebakes"
    end
  end

  %i[approve revise unhide recover].each do |operation|
    it "permits #{operation} when the stored raw is ordinary prose" do
      reply = Fabricate(:post, user: admin, topic: post.topic, raw: McpContentWriteHelpers::PROSE)
      name, args =
        case operation
        when :approve, :revise
          reviewable =
            Fabricate(
              :reviewable_queued_post_topic,
              category: allowed_category,
              target_created_by: recipient,
              payload: {
                raw: McpContentWriteHelpers::PROSE,
                title: "Seasonal queued garden observations",
                tags: [],
                archetype: "regular",
              },
            )
          action = operation == :approve ? "approve_post" : "revise_and_reject_post"
          ["discourse_perform_reviewable_action", reviewable_arguments(reviewable, action)]
        when :unhide
          reply.update!(hidden: true)
          reviewable = ReviewablePost.queue_for_review(reply)
          [
            "discourse_perform_reviewable_action",
            reviewable_arguments(reviewable, "approve_and_unhide"),
          ]
        else
          PostDestroyer.new(admin, reply).destroy
          ["discourse_post_set_deleted", { post_id: reply.id, deleted: false }]
        end
      isolated { expect_success(rpc(name, args)) }
      activate!
      expect_success(rpc(name, args))
    end
  end

  it "saves a draft without creating or updating any backup copy under a forum rule" do
    SiteSetting.backup_drafts_to_pm_length = 10
    args = { draft_key: Draft::NEW_TOPIC, reply: McpContentWriteHelpers::PROSE }
    isolated do
      expect_success(rpc("discourse_save_draft", args))
      expect(BackupDraftPost.where(user_id: admin.id).count).to eq(1)
    end
    activate!
    before_posts = Post.count
    expect_success(rpc("discourse_save_draft", args))
    aggregate_failures do
      expect(Draft.find_by!(user_id: admin.id, draft_key: Draft::NEW_TOPIC).data).to include(
        args[:reply],
      )
      expect(BackupDraftPost.where(user_id: admin.id).count).to eq(0),
      "DRAFT BACKUP: a backup post was created"
      expect(BackupDraftTopic.where(user_id: admin.id).count).to eq(0),
      "DRAFT BACKUP: a backup topic was created"
      expect(Post.count).to eq(before_posts), "DRAFT BACKUP: save created copied posts"
    end
  end

  it "leaves an existing backup copy unchanged when MCP saves under a PM-only rule" do
    SiteSetting.backup_drafts_to_pm_length = 10
    args = { draft_key: Draft::NEW_TOPIC, reply: McpContentWriteHelpers::PROSE }
    data = expect_success(rpc("discourse_save_draft", args))
    backup = BackupDraftPost.find_by!(user_id: admin.id).post
    snapshot = backup.attributes.slice("raw", "cooked", "version", "updated_at")
    changed =
      args.merge(
        sequence: data.fetch("sequence"),
        reply: "More ordinary observations about our garden and the changing seasons.",
      )
    isolated do
      expect_success(rpc("discourse_save_draft", changed))
      expect(backup.reload.raw).to include(changed[:reply])
    end
    activate!(:pm)
    expect_success(rpc("discourse_save_draft", changed))
    expect(backup.reload.attributes.slice(*snapshot.keys)).to eq(snapshot),
    "DRAFT BACKUP: existing copy changed"
  end

  %i[admin member].each do |role|
    it "answers restricted SetPostDeleted like a missing post before #{role} permissions" do
      actor = role == :admin ? admin : Fabricate(:user, trust_level: TrustLevel[1])
      actor_token = role == :admin ? token : issue_token(actor)
      topic = Fabricate(:topic, user: admin, category: restricted_category, archived: true)
      Fabricate(:post, user: admin, topic: topic)
      restricted = Fabricate(:post, user: actor, topic: topic)
      args = { post_id: restricted.id, deleted: true }
      isolated do
        baseline = rpc("discourse_post_set_deleted", args, access_token: actor_token)
        if role == :admin
          expect_success(baseline)
        else
          expect(baseline["status"]).to eq(403)
        end
      end
      activate!
      missing =
        rpc(
          "discourse_post_set_deleted",
          args.merge(post_id: McpContentWriteHelpers::MISSING_ID),
          access_token: actor_token,
        )
      state = content_state
      response = rpc("discourse_post_set_deleted", args, access_token: actor_token)
      expect(response).to eq(missing)
      expect_refusal(response)
      expect(content_state).to eq(state)
    end

    it "answers restricted SetPostDeleted recovery like missing before #{role} permissions" do
      actor = role == :admin ? admin : Fabricate(:user, trust_level: TrustLevel[1])
      actor_token = role == :admin ? token : issue_token(actor)
      topic = Fabricate(:topic, user: admin, category: restricted_category)
      Fabricate(:post, user: admin, topic: topic)
      restricted = Fabricate(:post, user: actor, topic: topic)
      PostDestroyer.new(actor, restricted).destroy
      SiteSetting.max_post_deletions_per_day = 0 if role == :member
      args = { post_id: restricted.id, deleted: false }
      isolated do
        baseline = rpc("discourse_post_set_deleted", args, access_token: actor_token)
        if role == :admin
          expect_success(baseline)
        else
          expect(baseline["status"]).to eq(403)
        end
      end
      activate!
      missing =
        rpc(
          "discourse_post_set_deleted",
          args.merge(post_id: McpContentWriteHelpers::MISSING_ID),
          access_token: actor_token,
        )
      state = content_state
      response = rpc("discourse_post_set_deleted", args, access_token: actor_token)
      expect(response).to eq(missing)
      expect_refusal(response)
      expect(content_state).to eq(state)
    end
  end

  describe "approve_post_closed" do
    def queued_topic(payload = {}, **attributes)
      Fabricate(
        :reviewable_queued_post_topic,
        category: allowed_category,
        target_created_by: recipient,
        payload: {
          raw: McpContentWriteHelpers::PROSE,
          title: "Queued observations about seasonal gardens",
          tags: [],
          archetype: "regular",
        }.merge(payload),
        **attributes,
      )
    end

    def approve_arguments(reviewable, action = "approve_post")
      { reviewable_id: reviewable.id, action_id: action, confirm: true }
    end

    it "checks stored raw before approve_post_closed publishes a queued reply" do
      post.topic.update!(closed: true)
      raw = "Please read [the earlier discussion](/t/garden/99620001) before replying."
      reviewable = queued_topic({ raw: raw }, topic: post.topic)
      args = approve_arguments(reviewable, "approve_post_closed")
      isolated do
        expect_success(rpc("discourse_perform_reviewable_action", args))
        expect(reviewable.reload.status).to eq("approved")
        expect(reviewable.target.raw).to eq(raw)
        expect(reviewable.target.topic_id).to eq(post.topic_id)
      end
      activate!
      assert_reference_write("discourse_perform_reviewable_action", args)
    end

    it "permits approve_post_closed with ordinary stored prose" do
      post.topic.update!(closed: true)
      reviewable = queued_topic({}, topic: post.topic)
      activate!
      expect_success(
        rpc(
          "discourse_perform_reviewable_action",
          approve_arguments(reviewable, "approve_post_closed"),
        ),
      )
      expect(reviewable.reload.status).to eq("approved")
      expect(reviewable.target.raw).to eq(McpContentWriteHelpers::PROSE)
      expect(reviewable.target.topic_id).to eq(post.topic_id)
    end
  end

  describe "revise_and_reject_post" do
    before do
      SiteSetting.unique_posts_mins = 0
      Discourse.stubs(:current_hostname).returns("review-five-site.example")
      Discourse.stubs(:base_url).returns("https://review-five-site.example")
    end

    def queued_reply
      Fabricate(
        :reviewable_queued_post,
        id: 112_850_020,
        topic: post.topic,
        category: allowed_category,
        target_created_by: recipient,
        payload: {
          raw: McpContentWriteHelpers::PROSE,
          archetype: "regular",
        },
      )
    end

    def revise_and_reject(reviewable)
      rpc(
        "discourse_perform_reviewable_action",
        { reviewable_id: reviewable.id, action_id: "revise_and_reject_post", confirm: true },
      )
    end

    it "refuses revise_and_reject_post under private_messages without persisting a system PM" do
      reviewable = queued_reply
      activate!(:pm)
      expected = reference_error
      before_state = content_state
      before_pm_ids = Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)
      response = revise_and_reject(reviewable)
      aggregate_failures do
        expect_reference_refusal(response)
        expect(response).to eq(expected), "SYSTEM PM: revise_and_reject_post was accepted"
        expect(Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)).to eq(
          before_pm_ids,
        ),
        "SYSTEM PM ATOMICITY: revise_and_reject_post persisted a private message"
        expect(content_state).to eq(before_state),
        "SYSTEM PM ATOMICITY: reviewable or content changed"
      end
    end

    it "permits revise_and_reject_post on an allowed target under the forum rule alone" do
      reviewable = queued_reply
      activate!
      before_pm_ids = Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)
      target_post_ids = post.topic.posts.pluck(:id)
      data = expect_success(revise_and_reject(reviewable))
      expect(data.fetch("reviewable_id")).to eq(reviewable.id)
      expect(reviewable.reload.status).to eq("rejected")
      message = Topic.where(archetype: Archetype.private_message).where.not(id: before_pm_ids).sole
      expect(message.subtype).to eq(TopicSubtype.system_message)
      expect(message.topic_allowed_users.pluck(:user_id)).to include(recipient.id)
      expect(message.first_post.raw).to include(reviewable.payload.fetch("raw"))
      expect(post.topic.posts.pluck(:id)).to eq(target_post_ids)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
