# frozen_string_literal: true

RSpec.describe ModerationNotice do
  fab!(:moderator)
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    SiteSetting.hide_post_sensitivity = Reviewable.sensitivities[:low]
    SiteSetting.notify_users_after_responses_deleted_on_flagged_post = true
    SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
    Jobs::SendSystemMessage.clear
  end

  describe "notices from review actions" do
    shared_examples "notice source attribution" do |action:, source:, dsa_enabled:|
      it "describes #{source} detection for #{action} with DSA #{dsa_enabled ? "enabled" : "disabled"}" do
        enable_dsa_reporting if dsa_enabled
        post = Fabricate(:post, user: author)
        reply =
          PostCreator.create(
            Fabricate(:user),
            topic_id: post.topic_id,
            reply_to_post_number: post.post_number,
            raw: "This is a reply to the flagged post.",
          )
        post.update!(reply_count: 1)
        reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
        if source != :community
          reviewable.reviewable_scores.first.update!(
            user_id: Discourse::SYSTEM_USER_ID,
            reason: "watched_word",
          )
        end
        if source == :mixed
          PostActionCreator.inappropriate(Fabricate(:user, refresh_auto_groups: true), post)
        end
        Jobs::SendSystemMessage.clear

        reviewable.perform(moderator, action)
        jobs = Jobs::SendSystemMessage.jobs.map { |job| job["args"].first.deep_symbolize_keys }
        jobs.each { |args| Jobs::SendSystemMessage.new.execute(args) }

        notices =
          Post.where(topic_id: Topic.private_messages.select(:id)).order(:id).last(jobs.size)
        expected_detection = source == :automated ? "an automated flag" : "flags from the community"
        expect(notices).to be_present
        notices.each do |notice|
          if action == :agree_and_hide
            expect(notice.raw).to include("hidden by a moderator due to")
            expect(notice.topic.title).to eq(
              (
                if source == :automated
                  "Post hidden by an automated flag"
                else
                  "Post hidden by community flags"
                end
              ),
            )
          else
            expect(notice.raw).to include("a staff member opted to remove it.")
            expect(notice.topic.title).to eq(
              (
                if notice.topic.allowed_users.exists?(id: author.id)
                  "Flagged post removed by staff"
                else
                  "Reply removed from flagged post by staff"
                end
              ),
            )
          end
          expect(notice.raw).to include(
            (
              if action == :agree_and_hide
                expected_detection
              else
                "This post was flagged #{source == :automated ? "automatically" : "by the community"} and a staff member opted to remove it."
              end
            ),
          )
          expect(notice.raw).to include("an automated check indicates") if source == :automated
          expect(notice.raw).to include("the community feels") if source != :automated
          if dsa_enabled
            expect(notice.raw).to include("To appeal this decision, contact appeals@example.com")
          end
        end
        expect(jobs.size).to eq(action.to_s.end_with?("_replies") ? 2 : 1)
        expect(reply.reload.deleted_at).to be_present if action.to_s.end_with?("_replies")
      end
    end

    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :community,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :community,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :automated,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :automated,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :mixed,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :agree_and_hide,
                     source: :mixed,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :community,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :community,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :automated,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :automated,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :mixed,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree,
                     source: :mixed,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :community,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :community,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :automated,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :automated,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :mixed,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore,
                     source: :mixed,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :community,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :community,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :automated,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :automated,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :mixed,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_agree_replies,
                     source: :mixed,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :community,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :community,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :automated,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :automated,
                     dsa_enabled: true
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :mixed,
                     dsa_enabled: false
    include_examples "notice source attribution",
                     action: :delete_and_ignore_replies,
                     source: :mixed,
                     dsa_enabled: true

    it "identifies an authorized category moderator and the automated source" do
      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      category_moderator = Fabricate(:user, refresh_auto_groups: true)
      group.add(category_moderator)
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)
      post = Fabricate(:post, user: author, topic: Fabricate(:topic, category:))
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(category_moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include(
        "This post was hidden by a moderator due to an automated flag",
      )
    end

    it "identifies an automated check when a moderator hides a post again" do
      post = Fabricate(:post, user: author, hidden_at: 1.day.ago)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include(
        "An automated check flagged this post and a moderator hid it.",
      )
      expect(Post.last.topic.title).to eq("Post hidden by an automated flag, staff notified")
    end

    it "keeps notice wording independent of DSA classification" do
      enable_dsa_reporting
      notices =
        [
          nil,
          {
            community_rule: {
              "ground" => "Terms, section 3",
              "explanation" => "Personal attacks are prohibited.",
            },
            category: "STATEMENT_CATEGORY_DATA_PROTECTION_AND_PRIVACY_VIOLATIONS",
          },
        ].map do |classification|
          post = Fabricate(:post, user: author)
          reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

          reviewable.perform(moderator, :agree_and_hide, dsa_classification: classification)
          args = Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys
          Jobs::SendSystemMessage.new.execute(args)

          expect(DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id).status).to eq(
            classification ? "ready" : "pending",
          )
          Post.last.raw.gsub(post.url, "/flagged-post")
        end

      expect(notices.first).to eq(notices.last)
    end

    it "identifies the moderator when a post is hidden again" do
      post = Fabricate(:post, user: author, hidden_at: 1.day.ago)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(moderator, :agree_and_hide)
      args = Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys
      Jobs::SendSystemMessage.new.execute(args)

      expect(Post.last.raw).to include("The community flagged this post and a moderator hid it.")
      expect(Post.last.topic.title).to eq("Post hidden by community flags, staff notified")
    end

    it "retains automated detection and appeal facts after scores and settings change before delivery" do
      enable_dsa_reporting
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      args = Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys
      reviewable.reviewable_scores.update_all(user_id: flagger.id, reason: nil)
      SiteSetting.dsa_reporting_enabled = false
      SiteSetting.dsa_moderation_appeal_email = "changed@example.com"
      Jobs::SendSystemMessage.new.execute(args)

      expect(Post.last.raw).to include("hidden by a moderator due to an automated flag")
      expect(Post.last.raw).to include("To appeal this decision, contact appeals@example.com")
    end
  end

  describe "template compatibility" do
    shared_examples "a customized notice body" do |message_type:|
      it "preserves the customized #{message_type} body" do
        customized_body = "Custom instructions for this site."
        TranslationOverride.upsert!(
          :en,
          "system_messages.#{message_type}.text_body_template",
          customized_body,
        )
        options =
          ModerationNotice.new(automated_detection: true).message_options(
            recipient: author,
            message_type:,
            post_action_type_id: PostActionType.types[:inappropriate],
          )

        notice = SystemMessage.create(author, message_type, options)

        expect(notice.raw).to eq(customized_body)
      end
    end

    include_examples "a customized notice body", message_type: "post_hidden"
    include_examples "a customized notice body", message_type: "post_hidden_again"
    include_examples "a customized notice body", message_type: "flags_agreed_and_post_deleted"
    include_examples "a customized notice body",
                     message_type: "flags_agreed_and_post_deleted_for_responders"

    it "uses the English fallback for a British English recipient" do
      SiteSetting.allow_user_locale = true
      author.update!(locale: "en_GB")
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include("hidden by a moderator due to an automated flag")
      expect(Post.last.raw).to include("an automated check indicates")
      expect(Post.last.topic.title).to eq("Post hidden by an automated flag")
    end

    it "uses the English fallback on a British English site" do
      SiteSetting.default_locale = "en_GB"
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include("hidden by a moderator due to an automated flag")
      expect(Post.last.raw).to include("an automated check indicates")
      expect(Post.last.topic.title).to eq("Post hidden by an automated flag")
    end

    it "corrects the explanation interpolated into a customized body" do
      TranslationOverride.upsert!(
        :en,
        "system_messages.post_hidden.text_body_template",
        "CUSTOM %{flag_reason} END",
      )
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to start_with("CUSTOM Your post was flagged")
      expect(Post.last.raw).to include("an automated check indicates")
      expect(Post.last.raw).to end_with("END")
      expect(Post.last.topic.title).to eq("Post hidden by an automated flag")
    end

    it "uses a translated variant when a fallback base override is shadowed" do
      SiteSetting.allow_user_locale = true
      author.update!(locale: "de")
      TranslationOverride.upsert!(
        :en,
        "system_messages.post_hidden.text_body_template",
        "ENGLISH BASE",
      )
      TranslationOverride.upsert!(
        :de,
        "system_messages.post_hidden.automated.text_body_template",
        "DEUTSCHE VARIANTE",
      )
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to eq("DEUTSCHE VARIANTE")
    end

    it "keeps a translated explanation until its automated variant is available" do
      SiteSetting.default_locale = "de"
      TranslationOverride.upsert!(
        :de,
        "system_messages.post_hidden.automated.text_body_template",
        "Lokaler Hinweis %{flag_reason}",
      )
      expected_reason =
        I18n.t("flag_reasons.inappropriate", locale: :de, base_path: Discourse.base_path)
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to eq("Lokaler Hinweis #{expected_reason}")
    end

    it "preserves an existing translated body until the variant is translated" do
      SiteSetting.allow_user_locale = true
      author.update!(locale: "de")
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to start_with("Hallo,")
      expect(Post.last.topic.title).to eq("Beitrag versteckt wegen Community-Meldungen")
    end

    it "uses a variant translated for the recipient locale" do
      SiteSetting.allow_user_locale = true
      author.update!(locale: "de")
      TranslationOverride.upsert!(
        :de,
        "system_messages.post_hidden.moderator.text_body_template",
        "Lokaler Hinweis.",
      )
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to eq("Lokaler Hinweis.")
    end

    it "preserves a customized subject while disclosing automated detection in the body" do
      TranslationOverride.upsert!(
        :en,
        "system_messages.post_hidden.subject_template",
        "A message about your post",
      )
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include(
        "This post was hidden by a moderator due to an automated flag",
      )
      expect(Post.last.topic.title).to eq("A message about your post")
    end

    it "preserves a customized flag explanation" do
      customized_reason = "A customized explanation of this flag."
      TranslationOverride.upsert!(:en, "flag_reasons.inappropriate", customized_reason)
      post = Fabricate(:post, user: author)
      reviewable = PostActionCreator.inappropriate(flagger, post).reviewable
      reviewable.reviewable_scores.first.update!(
        user_id: Discourse::SYSTEM_USER_ID,
        reason: "watched_word",
      )

      reviewable.perform(moderator, :agree_and_hide)
      Jobs::SendSystemMessage.new.execute(
        Jobs::SendSystemMessage.jobs.last["args"].first.deep_symbolize_keys,
      )

      expect(Post.last.raw).to include(customized_reason)
      expect(Post.last.raw).to include(
        "This post was hidden by a moderator due to an automated flag",
      )
    end
  end

  describe "automated flag explanations" do
    it "preserves the existing label when a responder has no seeded explanation" do
      message_type = "flags_agreed_and_post_deleted_for_responders"
      options =
        ModerationNotice.new(automated_detection: true).message_options(
          recipient: author,
          message_type:,
          post_action_type_id: PostActionType.types[:illegal],
        )

      notice =
        SystemMessage.create(
          author,
          message_type,
          options.merge(
            flag_reason: "Illegal",
            url: "/flagged-post",
            flagged_post_raw_content: "The flagged post.",
            flagged_post_response_raw_content: "A response to the flagged post.",
          ),
        )

      expect(notice.raw).to include("\n\nIllegal\n\n")
      expect(notice.raw).to include(
        "This post was flagged automatically and a staff member opted to remove it.",
      )
    end

    shared_examples "an automated flag explanation" do |flag_type:, message_type:, explanation:|
      it "attributes #{flag_type} to an automated check in #{message_type}" do
        options =
          ModerationNotice.new(automated_detection: true).message_options(
            recipient: author,
            message_type:,
            post_action_type_id: PostActionType.types[flag_type],
          )

        notice =
          SystemMessage.create(
            author,
            message_type,
            options.merge(
              url: "/flagged-post",
              flagged_post_raw_content: "The flagged post.",
              flagged_post_response_raw_content: "A response to the flagged post.",
            ),
          )

        expect(notice.raw).to include(explanation)
        expect(notice.raw).to include(
          "This post was flagged automatically and a staff member opted to remove it.",
        )
      end
    end

    include_examples "an automated flag explanation",
                     flag_type: :off_topic,
                     message_type: "flags_agreed_and_post_deleted",
                     explanation: "an automated check indicates it is not a good fit for the topic"
    include_examples "an automated flag explanation",
                     flag_type: :off_topic,
                     message_type: "flags_agreed_and_post_deleted_for_responders",
                     explanation: "an automated check indicates it is not a good fit for the topic"
    include_examples "an automated flag explanation",
                     flag_type: :inappropriate,
                     message_type: "flags_agreed_and_post_deleted",
                     explanation: "an automated check indicates it is offensive"
    include_examples "an automated flag explanation",
                     flag_type: :inappropriate,
                     message_type: "flags_agreed_and_post_deleted_for_responders",
                     explanation: "an automated check indicates it is offensive"
    include_examples "an automated flag explanation",
                     flag_type: :illegal,
                     message_type: "flags_agreed_and_post_deleted",
                     explanation: "an automated check indicates it might be breaking the law"
    include_examples "an automated flag explanation",
                     flag_type: :spam,
                     message_type: "flags_agreed_and_post_deleted",
                     explanation: "an automated check indicates it is an advertisement"
    include_examples "an automated flag explanation",
                     flag_type: :spam,
                     message_type: "flags_agreed_and_post_deleted_for_responders",
                     explanation: "an automated check indicates it is an advertisement"
    include_examples "an automated flag explanation",
                     flag_type: :notify_moderators,
                     message_type: "flags_agreed_and_post_deleted",
                     explanation:
                       "an automated check indicates something about the post requires manual intervention"
    include_examples "an automated flag explanation",
                     flag_type: :notify_moderators,
                     message_type: "flags_agreed_and_post_deleted_for_responders",
                     explanation:
                       "an automated check indicates something about the post requires manual intervention"
  end
end
