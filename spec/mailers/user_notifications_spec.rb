# frozen_string_literal: true

RSpec.describe UserNotifications do
  let(:user) { Fabricate(:admin) }

  describe "#get_context_posts" do
    it "does not include hidden/deleted/user_deleted posts in context" do
      post1 = create_post
      _post2 = Fabricate(:post, topic: post1.topic, deleted_at: 1.day.ago)
      _post3 = Fabricate(:post, topic: post1.topic, user_deleted: true)
      _post4 = Fabricate(:post, topic: post1.topic, hidden: true)
      _post5 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:moderator_action])
      _post6 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:small_action])
      _post7 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:whisper])
      last = Fabricate(:post, topic: post1.topic)

      post1.user.user_option.email_previous_replies = UserOption.previous_replies_type[:always]

      # default is only post #1
      expect(UserNotifications.get_context_posts(last, nil, post1.user).count).to eq(1)
      # staff members can also see the whisper
      moderator = build(:moderator)
      moderator.user_option = UserOption.new
      moderator.user_option.email_previous_replies = UserOption.previous_replies_type[:always]
      tu = TopicUser.new(topic: post1.topic, user: moderator)
      expect(UserNotifications.get_context_posts(last, tu, tu.user).count).to eq(2)
    end

    it "allows users to control context" do
      post1 = create_post
      _post2 = Fabricate(:post, topic: post1.topic)
      post3 = Fabricate(:post, topic: post1.topic)

      user = Fabricate(:user)
      TopicUser.change(user.id, post1.topic_id, last_emailed_post_number: 1)
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: post1.topic_id)
      # to avoid reloads after update_columns
      user = topic_user.user
      user.user_option.update_columns(
        email_previous_replies: UserOption.previous_replies_type[:unless_emailed],
      )

      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(1)

      user.user_option.update_columns(
        email_previous_replies: UserOption.previous_replies_type[:never],
      )
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(0)

      user.user_option.update_columns(
        email_previous_replies: UserOption.previous_replies_type[:always],
      )
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(2)

      SiteSetting.private_email = true
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(0)
    end
  end

  describe ".signup" do
    subject(:email) { UserNotifications.signup(user) }

    it "works" do
      expect(email.to).to eq([user.email])
      expect(email.subject).to be_present
      expect(email.from).to eq([SiteSetting.notification_email])
      expect(email.body).to be_present
    end
  end

  describe ".forgot_password" do
    subject(:email) { UserNotifications.forgot_password(user) }

    it "works" do
      expect(email.to).to eq([user.email])
      expect(email.subject).to be_present
      expect(email.from).to eq([SiteSetting.notification_email])
      expect(email.body).to be_present
    end
  end

  describe ".post_approved" do
    fab!(:post)

    it "works" do
      subject =
        UserNotifications.post_approved(user, { notification_data_hash: { post_url: post.url } })

      expect(subject.to).to eq([user.email])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end
  end

  describe ".confirm_new_email" do
    let(:opts) { { requested_by_admin: requested_by_admin, email_token: token } }
    let(:token) { "test123" }

    context "when requested by admin" do
      let(:requested_by_admin) { true }

      it "uses the requested by admin template" do
        expect(UserNotifications.confirm_new_email(user, opts).body).to include(
          "This email change was requested by a site admin.",
        )
      end
    end

    context "when not requested by admin" do
      let(:requested_by_admin) { false }

      it "uses the normal template" do
        expect(UserNotifications.confirm_new_email(user, opts).body).not_to include(
          "This email change was requested by a site admin.",
        )
      end
    end
  end

  describe ".email_login" do
    subject(:email) { UserNotifications.email_login(user, email_token: email_token) }

    let(:email_token) do
      Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login]).token
    end

    it "generates the right email" do
      expect(email.to).to eq([user.email])
      expect(email.from).to eq([SiteSetting.notification_email])

      expect(email.subject).to eq(
        I18n.t("user_notifications.email_login.subject_template", email_prefix: SiteSetting.title),
      )

      expect(email.body.to_s).to match(
        I18n.t(
          "user_notifications.email_login.text_body_template",
          site_name: SiteSetting.title,
          base_url: Discourse.base_url,
          email_token: email_token,
        ),
      )
    end
  end

  describe ".digest" do
    subject(:email) { UserNotifications.digest(user) }

    after { Discourse.redis.keys("summary-new-users:*").each { |key| Discourse.redis.del(key) } }

    context "without new topics" do
      it "doesn't send the email" do
        expect(email.to).to be_blank
      end
    end

    context "with topics only from new users" do
      let!(:new_today) do
        Fabricate(
          :topic,
          user: Fabricate(:user, trust_level: TrustLevel[0], created_at: 10.minutes.ago),
          title: "Hey everyone look at me",
        )
      end
      let!(:new_yesterday) do
        Fabricate(
          :topic,
          user: Fabricate(:user, trust_level: TrustLevel[0], created_at: 25.hours.ago),
          created_at: 25.hours.ago,
          title: "This topic is of interest to you",
        )
      end

      it "returns topics from new users if they're more than 24 hours old" do
        expect(email.to).to eq([user.email])
        html = email.html_part.body.to_s
        expect(html).to include(new_yesterday.title)
        expect(html).to_not include(new_today.title)
      end
    end

    context "with new topics" do
      fab!(:coding_horror)

      let!(:popular_topic) { Fabricate(:topic, user: coding_horror, created_at: 1.hour.ago) }

      let!(:another_popular_topic) do
        Fabricate(:topic, user: coding_horror, created_at: 1.hour.ago)
      end

      let!(:post) { Fabricate(:post, topic: popular_topic, post_number: 1) }

      let!(:another_post) { Fabricate(:post, topic: another_popular_topic, post_number: 1) }

      it "works" do
        expect(email.to).to eq([user.email])
        expect(email.subject).to be_present
        expect(email.from).to eq([SiteSetting.notification_email])
        expect(email.html_part.body.to_s).to be_present
        expect(email.text_part.body.to_s).to be_present
        expect(email.header["List-Unsubscribe"].to_s).to match(/\/email\/unsubscribe\/\h{64}/)
        expect(email.header["List-Unsubscribe-Post"].to_s).to eq("List-Unsubscribe=One-Click")
        expect(email.header["X-Discourse-Topic-Ids"].to_s).to eq(
          "#{another_popular_topic.id},#{popular_topic.id}",
        )
        expect(email.header["X-Discourse-Post-Ids"].to_s).to eq("#{another_post.id},#{post.id}")
        expect(email.html_part.body.to_s).to include("New Users")
      end

      it "doesn't include new user count if digest_after_minutes is low" do
        user.user_option.digest_after_minutes = 60
        expect(email.html_part.body.to_s).to_not include("New Users")
      end

      it "works with min_date string" do
        digest = UserNotifications.digest(user, since: 1.month.ago.to_date.to_s)
        expect(digest.html_part.body.to_s).to be_present
        expect(digest.text_part.body.to_s).to be_present
        expect(digest.html_part.body.to_s).to include("New Users")
      end

      it "includes email_prefix in email subject instead of site title" do
        SiteSetting.email_prefix = "Try Discourse"
        SiteSetting.title = "Discourse Meta"

        expect(email.subject).to match(/Try Discourse/)
        expect(email.subject).not_to match(/Discourse Meta/)
      end

      it "includes unread likes received count within the since date" do
        Fabricate(
          :notification,
          user: user,
          notification_type: Notification.types[:liked],
          created_at: 2.months.ago,
        )
        Fabricate(
          :notification,
          user: user,
          notification_type: Notification.types[:liked],
          read: true,
        )
        Fabricate(:notification, user: user, notification_type: Notification.types[:liked])
        Fabricate(:notification, user: user, notification_type: Notification.types[:liked])
        digest = UserNotifications.digest(user, since: 1.month.ago.to_date.to_s)
        parsed_html = Nokogiri::HTML5.fragment(digest.html_part.body.to_s)
        expect(parsed_html.css(".header-stat-count #likes_received_stat_count strong").text).to eq(
          "2",
        )
        expect(
          parsed_html.css(".header-stat-description #likes_received_stat_description strong").text,
        ).to eq("Likes Received")
      end

      it "excludes deleted topics and their posts" do
        deleted =
          Fabricate(
            :topic,
            user: Fabricate(:user),
            title: "Delete this topic plz",
            created_at: 1.hour.ago,
          )
        post =
          Fabricate(
            :post,
            topic: deleted,
            score: 100.0,
            post_number: 2,
            raw: "Your wish is my command",
            created_at: 1.hour.ago,
          )
        deleted.trash!
        html = email.html_part.body.to_s
        expect(html).to_not include deleted.title
        expect(html).to_not include post.raw
      end

      it "excludes shared drafts" do
        cat = Fabricate(:category)
        SiteSetting.shared_drafts_category = cat.id
        topic =
          Fabricate(:topic, title: "This is a draft", category_id: cat.id, created_at: 1.hour.ago)
        post =
          Fabricate(
            :post,
            topic: topic,
            score: 100.0,
            post_number: 2,
            raw: "secret draft content",
            created_at: 1.hour.ago,
          )
        html = email.html_part.body.to_s
        expect(html).to_not include topic.title
        expect(html).to_not include post.raw
      end

      it "excludes whispers and other post types that don't belong" do
        t =
          Fabricate(
            :topic,
            user: Fabricate(:user),
            title: "Who likes the same stuff I like?",
            created_at: 1.hour.ago,
          )
        whisper =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 2,
            raw: "You like weird stuff",
            post_type: Post.types[:whisper],
            created_at: 1.hour.ago,
          )
        mod_action =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 3,
            raw: "This topic unlisted",
            post_type: Post.types[:moderator_action],
            created_at: 1.hour.ago,
          )
        small_action =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 4,
            raw: "A small action",
            post_type: Post.types[:small_action],
            created_at: 1.hour.ago,
          )
        html = email.html_part.body.to_s
        expect(html).to_not include whisper.raw
        expect(html).to_not include mod_action.raw
        expect(html).to_not include small_action.raw
      end

      it "excludes deleted and hidden posts" do
        t =
          Fabricate(
            :topic,
            user: Fabricate(:user),
            title: "Post objectionable stuff here",
            created_at: 1.hour.ago,
          )
        deleted =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 2,
            raw: "This post is uncalled for",
            deleted_at: 5.minutes.ago,
            created_at: 1.hour.ago,
          )
        hidden =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 3,
            raw: "Try to find this post",
            hidden: true,
            hidden_at: 5.minutes.ago,
            hidden_reason_id: Post.hidden_reasons[:flagged_by_tl3_user],
            created_at: 1.hour.ago,
          )
        user_deleted =
          Fabricate(
            :post,
            topic: t,
            score: 100.0,
            post_number: 4,
            raw: "I regret this post",
            user_deleted: true,
            created_at: 1.hour.ago,
          )
        html = email.html_part.body.to_s
        expect(html).to_not include deleted.raw
        expect(html).to_not include hidden.raw
        expect(html).to_not include user_deleted.raw
      end

      it "excludes posts that are newer than editing grace period" do
        SiteSetting.editing_grace_period = 5.minutes
        too_new =
          Fabricate(
            :topic,
            user: Fabricate(:user),
            title: "Oops I need to edit this",
            created_at: 1.minute.ago,
          )
        _too_new_post =
          Fabricate(
            :post,
            user: too_new.user,
            topic: too_new,
            score: 100.0,
            post_number: 1,
            created_at: 1.minute.ago,
          )
        html = email.html_part.body.to_s
        expect(html).to_not include too_new.title
      end

      it "uses theme color" do
        cs =
          Fabricate(
            :color_scheme,
            name: "Fancy",
            color_scheme_colors: [
              Fabricate(:color_scheme_color, name: "header_primary", hex: "F0F0F0"),
              Fabricate(:color_scheme_color, name: "header_background", hex: "1E1E1E"),
            ],
          )
        theme =
          Fabricate(:theme, user_selectable: true, user: Fabricate(:admin), color_scheme_id: cs.id)

        theme.set_default!

        html = email.html_part.body.to_s
        expect(html).to include "F0F0F0"
        expect(html).to include "1E1E1E"
      end

      it "supports subfolder" do
        set_subfolder "/forum"
        html = email.html_part.body.to_s
        text = email.text_part.body.to_s
        expect(html).to be_present
        expect(text).to be_present
        expect(html).to_not include("/forum/forum")
        expect(text).to_not include("/forum/forum")
        expect(email.header["List-Unsubscribe"].to_s).to match(
          /http:\/\/test.localhost\/forum\/email\/unsubscribe\/\h{64}/,
        )
        expect(email.header["List-Unsubscribe-Post"].to_s).to eq("List-Unsubscribe=One-Click")

        topic_url = "http://test.localhost/forum/t/#{popular_topic.slug}/#{popular_topic.id}"
        expect(html).to include(topic_url)
        expect(text).to include(topic_url)
      end

      it "applies lang/xml:lang html attributes" do
        SiteSetting.default_locale = "pl_PL"
        html = email.html_part.to_s

        expect(html).to match(' lang="pl-PL"')
        expect(html).to match(' xml:lang="pl-PL"')
      end

      it "uses digest_attempted_at when user hasn't been seen in a while" do
        user.update!(last_seen_at: 7.days.ago)
        user.user_stat.update!(digest_attempted_at: 30.minutes.ago)
        expect(email.to).to be_nil
      end

      it "uses last_seen_at when user has been sent a digest in a while" do
        user.update!(last_seen_at: 30.minutes.ago)
        user.user_stat.update!(digest_attempted_at: 7.days.ago)
        expect(email.to).to be_nil
      end

      it "caps at 1 month when user has never been seen or sent a digest" do
        old_topic = Fabricate(:topic, created_at: 2.months.ago)

        user.update!(last_seen_at: nil)
        user.user_stat.update!(digest_attempted_at: nil)
        expect(email.to).to contain_exactly(user.email)

        html = email.html_part.body.to_s
        expect(html).not_to include(old_topic.title)
      end
    end
  end

  describe ".user_replied" do
    let(:response_by_user) { Fabricate(:user, name: "John Doe") }
    let(:category) { Fabricate(:category, name: "India") }
    let(:tag1) { Fabricate(:tag, name: "Taggo", public_topic_count: 1) }
    let(:tag2) { Fabricate(:tag, name: "Taggie", public_topic_count: 3) }
    let(:tag3) { Fabricate(:tag, name: "Teggo", public_topic_count: 2) }

    let(:hidden_tag) { Fabricate(:tag, name: "hidden") }
    let!(:hidden_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    let(:topic) do
      Fabricate(
        :topic,
        category: category,
        tags: [tag1, tag2, tag3, hidden_tag],
        title: "Super cool topic",
      )
    end
    let(:post) { Fabricate(:post, topic: topic, raw: "This is My super duper cool topic") }
    let(:response) { Fabricate(:basic_reply, topic: post.topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:replied_notification, user: user, post: response) }

    it "generates a correct email" do
      SiteSetting.default_email_in_reply_to = true

      # Fabricator is not fabricating this ...
      SiteSetting.email_subject =
        "[%{site_name}] %{optional_pm}%{optional_cat}%{optional_tags}%{topic_title}"
      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      # from should include full user name
      expect(mail[:from].display_names).to eql(["John Doe via Discourse"])

      # subject should include category name
      expect(mail.subject).to match(/India/)

      # subject should include tag names
      expect(mail.subject).to match(/Taggo/)
      expect(mail.subject).to match(/Taggie/)

      mail_html = mail.html_part.body.to_s

      expect(mail_html.scan(/My super duper cool topic/).count).to eq(1)
      expect(mail_html.scan(/In Reply To/).count).to eq(1)

      # 2 "visit topic" link
      expect(mail_html.scan(/Visit Topic/).count).to eq(2)

      # 2 respond to links cause we have 1 context post
      expect(mail_html.scan(/to respond/).count).to eq(2)

      # 1 unsubscribe
      expect(mail_html.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)

      # no In Reply To if user opts out
      user.user_option.email_in_reply_to = false
      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.html_part.body.to_s.scan(/In Reply To/).count).to eq(0)

      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      SiteSetting.prioritize_username_in_ux = false

      response.user.username = "bobmarley"
      response.user.name = "Bob Marley"
      response.user.save

      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      mail_html = mail.html_part.body.to_s
      expect(mail_html.scan(/>Bob Marley/).count).to eq(1)
      expect(mail_html.scan(/>bobmarley/).count).to eq(0)

      expect(mail.subject.scan(/#{tag1.name}/).count).to eq(1)
      expect(mail.subject.scan(/#{hidden_tag.name}/).count).to eq(0)

      SiteSetting.prioritize_username_in_ux = true

      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      mail_html = mail.html_part.body.to_s
      expect(mail_html.scan(/>Bob Marley/).count).to eq(0)
      expect(mail_html.scan(/>bobmarley/).count).to eq(1)
    end

    describe "number of tags shown in subject line" do
      describe "max_tags_per_email_subject siteSetting enabled" do
        before { SiteSetting.enable_max_tags_per_email_subject = true }

        it "should match max_tags_per_email_subject" do
          SiteSetting.email_subject =
            "[%{site_name}] %{optional_pm}%{optional_cat}%{optional_tags}%{topic_title}"
          SiteSetting.max_tags_per_topic = 1
          SiteSetting.max_tags_per_email_subject = 2

          mail =
            UserNotifications.user_replied(
              user,
              post: response,
              notification_type: notification.notification_type,
              notification_data_hash: notification.data_hash,
            )

          expect(mail.subject).to eq(
            "[Discourse] [#{category.name}] #{tag2.name} #{tag3.name} #{topic.title}",
          )
        end
      end

      describe "max_tags_per_email_subject siteSetting disabled" do
        before { SiteSetting.enable_max_tags_per_email_subject = false }

        it "should match max_tags_per_topic" do
          SiteSetting.email_subject =
            "[%{site_name}] %{optional_pm}%{optional_cat}%{optional_tags}%{topic_title}"
          SiteSetting.max_tags_per_topic = 2
          SiteSetting.max_tags_per_email_subject = 1

          mail =
            UserNotifications.user_replied(
              user,
              post: response,
              notification_type: notification.notification_type,
              notification_data_hash: notification.data_hash,
            )

          expect(mail.subject).to eq(
            "[Discourse] [#{category.name}] #{tag2.name} #{tag3.name} #{topic.title}",
          )
        end
      end
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.html_part.body.to_s).to_not include(response.raw)
      expect(mail.html_part.body.to_s).to_not include(topic.url)
      expect(mail.text_part.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(topic.url)
    end

    it "includes excerpt when post_excerpts_in_emails is enabled" do
      paragraphs = [
        "This is the first paragraph, but you should read more.",
        "And here is its friend, the second paragraph.",
      ]
      SiteSetting.post_excerpts_in_emails = true
      SiteSetting.post_excerpt_maxlength = paragraphs.first.length
      response.update!(raw: paragraphs.join("\n\n"))
      mail =
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      mail_html = mail.html_part.body.to_s
      expect(mail_html.scan(/#{paragraphs[0]}/).count).to eq(1)
      expect(mail_html.scan(/#{paragraphs[1]}/).count).to eq(0)
    end
  end

  describe ".user_posted" do
    let(:response_by_user) { Fabricate(:user, name: "John Doe", username: "john") }
    let(:topic) { Fabricate(:topic, title: "Super cool topic") }
    let(:post) { Fabricate(:post, topic: topic) }
    let(:response) { Fabricate(:post, topic: topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:posted_notification, user: user, post: response) }

    it "generates a correct email" do
      SiteSetting.enable_names = false
      mail =
        UserNotifications.user_posted(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      # from should not include full user name if "show user full names" is disabled
      expect(mail[:from].display_names).to_not eql(["John Doe"])

      # from should include username if "show user full names" is disabled
      expect(mail[:from].display_names).to eql(["john via Discourse"])

      # subject should not include category name
      expect(mail.subject).not_to match(/Uncategorized/)

      # 1 respond to links as no context by default
      expect(mail.html_part.body.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.body.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail =
        UserNotifications.user_posted(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.html_part.body.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(response.raw)
    end

    it "uses the original subject for staged users" do
      incoming_email =
        Fabricate(
          :incoming_email,
          subject: "Original Subject",
          post: post,
          topic: post.topic,
          user: user,
        )

      mail =
        UserNotifications.user_posted(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to match(/Super cool topic/)

      user.update!(staged: true)
      mail =
        UserNotifications.user_posted(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to eq("Re: Original Subject")

      another_post = Fabricate(:post, topic: topic)
      incoming_email.update!(post_id: another_post.id)

      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to match(/Super cool topic/)
    end
  end

  describe ".user_private_message" do
    let(:response_by_user) { Fabricate(:user, name: "", username: "john") }
    let(:topic) { Fabricate(:private_message_topic, title: "Super cool topic") }
    let(:post) { Fabricate(:post, topic: topic) }
    let(:response) { Fabricate(:post, topic: topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:private_message_notification, user: user, post: response) }

    it "generates a correct email" do
      SiteSetting.enable_names = true
      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      # from should include username if full user name is not provided
      expect(mail[:from].display_names).to eql(["john via Discourse"])

      # subject should include "[PM]"
      expect(mail.subject).to include("[PM] ")

      # 1 "visit message" link
      expect(mail.html_part.body.to_s.scan(/Visit Message/).count).to eq(1)

      # 1 respond to link
      expect(mail.html_part.body.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.body.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(topic.id, user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.html_part.body.to_s).to_not include(response.raw)
      expect(mail.html_part.body.to_s).to_not include(topic.url)
      expect(mail.text_part.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(topic.url)
    end

    it "doesn't include group name in subject" do
      group = Fabricate(:group)
      topic.allowed_groups = [group]
      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.subject).to include("[PM] ")
    end

    it "includes a list of participants (except for the destination user), groups first with member lists" do
      group1 = Fabricate(:group, name: "group1")
      group2 = Fabricate(:group, name: "group2")

      user1 = Fabricate(:user, username: "one", groups: [group1, group2])
      user2 = Fabricate(:user, username: "two", groups: [group1], staged: true)

      topic.allowed_users = [user, user1, user2]
      topic.allowed_groups = [group1, group2]

      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )

      expect(mail.body).to include(
        "[group1 (2)](http://test.localhost/g/group1), [group2 (1)](http://test.localhost/g/group2), [one](http://test.localhost/u/one), [two](http://test.localhost/u/two)",
      )
    end

    context "when SiteSetting.group_name_in_subject is true" do
      before { SiteSetting.group_in_subject = true }

      let(:group) { Fabricate(:group, name: "my_group") }
      let(:mail) do
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      end

      shared_examples "includes first group name" do
        it "includes first group name in subject" do
          expect(mail.subject).to include("[my_group] ")
        end

        context "when first group has full name" do
          it "includes full name in subject" do
            group.full_name = "My Group"
            group.save
            expect(mail.subject).to include("[My Group] ")
          end
        end
      end

      context "with one group in pm" do
        before { topic.allowed_groups = [group] }

        include_examples "includes first group name"
      end

      context "with multiple groups in pm" do
        let(:group2) { Fabricate(:group) }

        before { topic.allowed_groups = [group, group2] }

        include_examples "includes first group name"
      end

      context "with no groups in pm" do
        it "includes %{optional_pm} in subject" do
          expect(mail.subject).to include("[PM] ")
        end
      end
    end

    it "uses the original subject for staged users when topic was started via email" do
      incoming_email =
        Fabricate(
          :incoming_email,
          subject: "Original Subject",
          post: post,
          topic: topic,
          user: user,
        )

      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to match(/Super cool topic/)

      user.update!(staged: true)
      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to eq("Re: Original Subject")

      another_post = Fabricate(:post, topic: topic)
      incoming_email.update!(post_id: another_post.id)

      mail =
        UserNotifications.user_private_message(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      expect(mail.subject).to match(/Super cool topic/)
    end
  end

  it "adds a warning when mail limit is reached" do
    SiteSetting.max_emails_per_day_per_user = 2
    user = Fabricate(:user)

    user.email_logs.create!(email_type: "blah", to_address: user.email, user_id: user.id)

    post = Fabricate(:post)
    reply = Fabricate(:post, topic_id: post.topic_id)

    notification =
      Fabricate(
        :notification,
        topic_id: post.topic_id,
        post_number: reply.post_number,
        user: post.user,
        data: { original_username: "bob" }.to_json,
      )

    mail =
      UserNotifications.user_replied(
        user,
        post: reply,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash,
      )

    # WARNING: you reached the limit of 100 email notifications per day. Further emails will be suppressed.
    # Consider watching less topics or disabling mailing list mode.
    expect(mail.html_part.body.to_s).to match(I18n.t("user_notifications.reached_limit", count: 2))
    expect(mail.body.to_s).to match(I18n.t("user_notifications.reached_limit", count: 2))
  end

  def expects_build_with(condition)
    UserNotifications.any_instance.expects(:build_email).with(user.email, condition)
    mailer =
      UserNotifications.public_send(
        mail_type,
        user,
        notification_type: Notification.types[notification.notification_type],
        notification_data_hash: notification.data_hash,
        post: notification.post,
      )

    mailer.message
  end

  shared_examples "supports reply by email" do
    context "with reply_by_email" do
      it "should have allow_reply_by_email set when that feature is enabled" do
        expects_build_with(has_entry(:allow_reply_by_email, true))
      end
    end
  end

  shared_examples "no reply by email" do
    context "with reply_by_email" do
      it "doesn't support reply by email" do
        expects_build_with(Not(has_entry(:allow_reply_by_email, true)))
      end
    end
  end

  shared_examples "respect for private_email" do
    context "with private_email" do
      it "doesn't support reply by email" do
        SiteSetting.private_email = true

        mailer =
          UserNotifications.public_send(
            mail_type,
            user,
            notification_type: Notification.types[notification.notification_type],
            notification_data_hash: notification.data_hash,
            post: notification.post,
          )
        message = mailer.message

        topic = notification.post.topic
        expect(message.html_part.body.to_s).not_to include(topic.title)
        expect(message.html_part.body.to_s).not_to include(topic.slug)
        expect(message.text_part.body.to_s).not_to include(topic.title)
        expect(message.text_part.body.to_s).not_to include(topic.slug)
      end
    end
  end

  # The parts of emails that are derived from templates are translated
  shared_examples "sets user locale" do
    context "with set locale for translating templates" do
      it "sets the locale" do
        expects_build_with(has_key(:locale))
      end
    end
  end

  shared_examples "notification email building" do
    let(:post) { Fabricate(:post, user: user) }
    let(:mail_type) { "user_#{notification_type}" }
    let(:mail_template) { "user_notifications.#{mail_type}" }
    let(:username) { "walterwhite" }
    let(:notification) do
      Fabricate(
        :notification,
        user: user,
        topic: post.topic,
        notification_type: Notification.types[notification_type],
        post_number: post.post_number,
        data: { original_username: username }.to_json,
      )
    end

    describe "email building" do
      it "has a username" do
        expects_build_with(has_entry(:username, username))
      end

      it "has a url" do
        expects_build_with(has_key(:url))
      end

      it "has a template" do
        expects_build_with(has_entry(:template, mail_template))
      end

      it "overrides the html part" do
        expects_build_with(has_key(:html_override))
      end

      it "has a message" do
        expects_build_with(has_key(:message))
      end

      it "has a context" do
        expects_build_with(has_key(:context))
      end

      it "has an unsubscribe link" do
        expects_build_with(has_key(:add_unsubscribe_link))
      end

      it "has an post_id" do
        expects_build_with(has_key(:post_id))
      end

      it "has an topic_id" do
        expects_build_with(has_key(:topic_id))
      end

      it "should have user name as from_alias" do
        SiteSetting.enable_names = true
        SiteSetting.display_name_on_posts = true
        expects_build_with(has_entry(:from_alias, "#{user.name} via Discourse"))
      end

      it "should not have user name as from_alias if display_name_on_posts is disabled" do
        SiteSetting.enable_names = false
        SiteSetting.display_name_on_posts = false
        expects_build_with(has_entry(:from_alias, "walterwhite via Discourse"))
      end

      it "should explain how to respond" do
        expects_build_with(Not(has_entry(:include_respond_instructions, false)))
      end

      it "should not explain how to respond if the user is suspended" do
        User.any_instance.stubs(:suspended?).returns(true)
        expects_build_with(has_entry(:include_respond_instructions, false))
      end

      context "when customized" do
        let(:custom_body) do
          body = +<<~BODY
            You are now officially notified.
            %{header_instructions}
            %{message} %{respond_instructions}
            %{topic_title_url_encoded}
            %{site_title_url_encoded}
          BODY

          body << "%{context}" if notification_type != :invited_to_topic
          body
        end

        before do
          TranslationOverride.upsert!(
            SiteSetting.default_locale,
            "#{mail_template}.text_body_template",
            custom_body,
          )
        end

        it "shouldn't use the default html_override" do
          expects_build_with(Not(has_key(:html_override)))
        end
      end
    end
  end

  describe "user mentioned email" do
    include_examples "notification email building" do
      let(:notification_type) { :mentioned }
      include_examples "respect for private_email"
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "group mentioned email" do
    include_examples "notification email building" do
      let(:notification_type) { :group_mentioned }
      let(:post) { Fabricate(:private_message_post) }
      let(:user) { post.user }
      let(:mail_type) { "group_mentioned" }
      let(:mail_template) { "user_notifications.user_#{notification_type}_pm" }

      include_examples "respect for private_email"
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user replied" do
    include_examples "notification email building" do
      let(:notification_type) { :replied }
      include_examples "respect for private_email"
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user quoted" do
    include_examples "notification email building" do
      let(:notification_type) { :quoted }
      include_examples "respect for private_email"
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user posted" do
    include_examples "notification email building" do
      let(:notification_type) { :posted }
      include_examples "respect for private_email"
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user invited to a private message" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_private_message }
      let(:post) { Fabricate(:private_message_post) }
      let(:user) { post.user }
      let(:mail_template) { "user_notifications.user_#{notification_type}_pm" }

      include_examples "respect for private_email"
      include_examples "no reply by email"
      include_examples "sets user locale"
    end
  end

  describe "group invited to a private message" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_private_message }
      let(:post) { Fabricate(:private_message_post) }
      let(:user) { post.user }
      let(:group) { Fabricate(:group) }
      let(:mail_template) { "user_notifications.user_#{notification_type}_pm_group" }

      before do
        notification.data_hash[:group_id] = group.id
        notification.save!
      end

      it "should include the group name" do
        expects_build_with(has_entry(:group_name, group.name))
      end

      include_examples "respect for private_email"
      include_examples "no reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user invited to a topic" do
    let(:notification_type) { :invited_to_topic }

    include_examples "notification email building" do
      include_examples "respect for private_email"
      include_examples "no reply by email"
      include_examples "sets user locale"
    end

    context "when showing the right name in 'From' field" do
      let(:inviter) { Fabricate(:user) }
      let(:invitee) { Fabricate(:user) }

      let(:notification) do
        Fabricate(
          :notification,
          notification_type: Notification.types[:invited_to_topic],
          user: invitee,
          topic: post.topic,
          post_number: post.post_number,
          data: {
            topic_title: post.topic.title,
            display_username: inviter.username,
            original_user_id: inviter.id,
            original_username: inviter.username,
          }.to_json,
        )
      end

      let(:mailer) do
        UserNotifications.public_send(
          "user_invited_to_topic",
          invitee,
          notification_type: Notification.types[notification.notification_type],
          notification_data_hash: notification.data_hash,
          post: notification.post,
        )
      end

      it "sends the email as the inviter" do
        SiteSetting.enable_names = false

        expect(mailer.message.to_s).to include(
          "From: #{inviter.username} via #{SiteSetting.title} <#{SiteSetting.notification_email}>",
        )
      end

      it "sends the email as the inviter" do
        expect(mailer.message.to_s).to include(
          "From: #{inviter.name} via #{SiteSetting.title} <#{SiteSetting.notification_email}>",
        )
      end
    end
  end

  describe "watching first post" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_topic }
      include_examples "respect for private_email"
      include_examples "no reply by email"
      include_examples "sets user locale"
    end
  end

  # notification emails derived from templates are translated into the user's locale
  shared_context "with notification derived from template" do
    let(:user) { Fabricate(:user, locale: locale) }
    let(:mail_type) { mail_type }
    let(:notification) { Fabricate(:notification, user: user) }
  end

  describe "notifications from template" do
    context "when user locale is allowed" do
      before { SiteSetting.allow_user_locale = true }

      %w[
        signup
        signup_after_approval
        confirm_old_email
        notify_old_email
        confirm_new_email
        forgot_password
        admin_login
        account_created
      ].each do |mail_type|
        include_examples "with notification derived from template" do
          let(:locale) { "fr" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, "fr"))
          end
        end
      end
    end

    context "when user locale is not allowed" do
      before { SiteSetting.allow_user_locale = false }

      %w[
        signup
        signup_after_approval
        notify_old_email
        confirm_old_email
        confirm_new_email
        forgot_password
        admin_login
        account_created
      ].each do |mail_type|
        include_examples "with notification derived from template" do
          let(:locale) { "fr" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, "en"))
          end
        end
      end
    end
  end

  describe "#participants" do
    fab!(:group1) { Fabricate(:group, name: "group1") }
    fab!(:group2) { Fabricate(:group, name: "group2") }
    fab!(:group3) { Fabricate(:group, name: "group3") }
    fab!(:user1) { Fabricate(:user, username: "one", name: nil, groups: [group1, group2]) }
    fab!(:user2) { Fabricate(:user, username: "two", name: nil, groups: [group1]) }
    fab!(:user3) { Fabricate(:user, username: "three", name: nil, groups: [group3]) }
    fab!(:user4) { Fabricate(:user, username: "four", name: nil, groups: [group1, group3]) }
    fab!(:admin) { Fabricate(:admin, username: "admin", name: nil) }

    fab!(:topic) do
      t = Fabricate(:private_message_topic, title: "Super cool topic")
      t.allowed_users = [user1, user2, user3, user4, admin]
      t.allowed_groups = [group1]
      t
    end
    fab!(:posts) do
      [
        Fabricate(:post, topic: topic, post_number: 1, user: user2),
        Fabricate(:post, topic: topic, post_number: 2, user: user1),
        Fabricate(:post, topic: topic, post_number: 3, user: user2),
        Fabricate(:small_action, topic: topic, post_number: 4, user: admin),
        Fabricate(:post, topic: topic, post_number: 5, user: user4),
        Fabricate(:post, topic: topic, post_number: 6, user: user3),
        Fabricate(:post, topic: topic, post_number: 7, user: user4),
      ]
    end

    it "returns a list of participants (except for the recipient), groups first, followed by users in order of their last reply" do
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), " \
          "[four](http://test.localhost/u/four), [two](http://test.localhost/u/two), [one](http://test.localhost/u/one), " \
          "[admin](http://test.localhost/u/admin)",
      )
    end

    it "caps the list according to site setting" do
      SiteSetting.max_participant_names = 3
      list =
        "[group1 (3)](http://test.localhost/g/group1), [four](http://test.localhost/u/four), [two](http://test.localhost/u/two)"
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        I18n.t("user_notifications.more_pm_participants", participants: list, count: 2),
      )
    end

    it "orders groups by user count" do
      SiteSetting.max_participant_names = 3
      topic.allowed_groups = [group1, group2, group3]

      list =
        "[group1 (3)](http://test.localhost/g/group1), [group3 (2)](http://test.localhost/g/group3), [group2 (1)](http://test.localhost/g/group2)"
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        I18n.t("user_notifications.more_pm_participants", participants: list, count: 4),
      )
    end

    it "orders users by their last reply and user id" do
      expect(UserNotifications.participants(posts[-3], user4)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), " \
          "[two](http://test.localhost/u/two), [one](http://test.localhost/u/one), [three](http://test.localhost/u/three), " \
          "[admin](http://test.localhost/u/admin)",
      )
    end

    it "prefers full group names when available" do
      SiteSetting.max_participant_names = 2
      topic.allowed_groups = [group1, group2]

      group2.update!(full_name: "Awesome Group")

      list =
        "[group1 (3)](http://test.localhost/g/group1), [Awesome Group (1)](http://test.localhost/g/group2)"
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        I18n.t("user_notifications.more_pm_participants", participants: list, count: 4),
      )
    end

    it "always uses usernames when prioritize_username_in_ux is enabled" do
      user4.update!(name: "James Bond")
      user1.update!(name: "Indiana Jones")

      SiteSetting.prioritize_username_in_ux = true
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), " \
          "[four](http://test.localhost/u/four), [two](http://test.localhost/u/two), [one](http://test.localhost/u/one), " \
          "[admin](http://test.localhost/u/admin)",
      )

      SiteSetting.prioritize_username_in_ux = false
      expect(UserNotifications.participants(posts.last, user3)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), " \
          "[James Bond](http://test.localhost/u/four), [two](http://test.localhost/u/two), [Indiana Jones](http://test.localhost/u/one), " \
          "[admin](http://test.localhost/u/admin)",
      )
    end

    it "reveals the email address of staged users if enabled" do
      user4.update!(staged: true, email: "james.bond@mi6.invalid")
      user1.update!(staged: true, email: "indiana.jones@example.com")

      SiteSetting.prioritize_username_in_ux = true
      expect(UserNotifications.participants(posts.last, user3, reveal_staged_email: true)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), james.bond@mi6.invalid, [two](http://test.localhost/u/two), " \
          "indiana.jones@example.com, [admin](http://test.localhost/u/admin)",
      )
    end

    it "does only include human users" do
      topic.allowed_users << Discourse.system_user

      expect(UserNotifications.participants(posts.last, user3)).to eq(
        "[group1 (3)](http://test.localhost/g/group1), " \
          "[four](http://test.localhost/u/four), [two](http://test.localhost/u/two), [one](http://test.localhost/u/one), " \
          "[admin](http://test.localhost/u/admin)",
      )
    end
  end

  describe ".account_silenced" do
    fab!(:user_history) { Fabricate(:user_history, action: UserHistory.actions[:silence_user]) }

    it "adds the silenced_till date in user's timezone" do
      user.user_option.timezone = "Asia/Tbilisi" # GMT+4
      user.silenced_till = DateTime.parse("May 25, 2020, 12:00pm")

      mail = UserNotifications.account_silenced(user, { user_history: user_history })

      expect(mail.body).to include("May 25, 2020,  4:00pm")
    end

    context "when user doesn't have timezone set" do
      before { user.user_option.timezone = nil }

      it "doesn't raise error" do
        expect { UserNotifications.account_silenced(user) }.not_to raise_error
      end

      it "adds the silenced_till date in UTC" do
        date = "May 25, 2020, 12:00pm"
        user.silenced_till = DateTime.parse(date)

        mail = UserNotifications.account_silenced(user, { user_history: user_history })

        expect(mail.body).to include(date)
      end
    end

    context "when user timezone is invalid" do
      before { user.user_option.timezone = "" }

      it "doesn't raise error" do
        expect { UserNotifications.account_silenced(user) }.not_to raise_error
      end

      it "adds the silenced_till date in UTC" do
        date = "May 25, 2020, 12:00pm"
        user.silenced_till = DateTime.parse(date)

        mail = UserNotifications.account_silenced(user, { user_history: user_history })

        expect(mail.body).to include(date)
      end
    end
  end

  describe ".account_suspended" do
    fab!(:user_history) { Fabricate(:user_history, action: UserHistory.actions[:suspend_user]) }

    it "adds the suspended_till date in user's timezone" do
      user.user_option.timezone = "Asia/Tbilisi" # GMT+4
      user.suspended_till = DateTime.parse("May 25, 2020, 12:00pm")

      mail = UserNotifications.account_suspended(user, { user_history: user_history })

      expect(mail.body).to include("May 25, 2020,  4:00pm")
    end

    context "when user doesn't have timezone set" do
      before { user.user_option.timezone = nil }

      it "doesn't raise error" do
        expect { UserNotifications.account_suspended(user) }.not_to raise_error
      end

      it "adds the suspended_till date in UTC" do
        date = "May 25, 2020, 12:00pm"
        user.suspended_till = DateTime.parse(date)

        mail = UserNotifications.account_suspended(user, { user_history: user_history })

        expect(mail.body).to include(date)
      end
    end

    context "when user timezone is invalid" do
      before { user.user_option.timezone = "" }

      it "doesn't raise error" do
        expect { UserNotifications.account_suspended(user) }.not_to raise_error
      end

      it "adds the suspended_till date in UTC" do
        date = "May 25, 2020, 12:00pm"
        user.suspended_till = DateTime.parse(date)

        mail = UserNotifications.account_suspended(user, { user_history: user_history })

        expect(mail.body).to include(date)
      end
    end
  end
end
