require "rails_helper"

describe UserNotifications do

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
      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:unless_emailed])

      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(1)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:never])
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(0)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:always])
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(2)

      SiteSetting.private_email = true
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(0)
    end

  end

  describe ".signup" do

    subject { UserNotifications.signup(user) }

    it "works" do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end

  end

  describe ".forgot_password" do

    subject { UserNotifications.forgot_password(user) }

    it "works" do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end

  end

  describe '.email_login' do
    let(:email_token) { user.email_tokens.create!(email: user.email).token }
    subject { UserNotifications.email_login(user, email_token: email_token) }

    it "generates the right email" do
      expect(subject.to).to eq([user.email])
      expect(subject.from).to eq([SiteSetting.notification_email])

      expect(subject.subject).to eq(I18n.t(
        'user_notifications.email_login.subject_template',
        email_prefix: SiteSetting.title
      ))

      expect(subject.body.to_s).to match(I18n.t(
        'user_notifications.email_login.text_body_template',
        site_name: SiteSetting.title,
        base_url: Discourse.base_url,
        email_token: email_token
      ))
    end
  end

  describe '.digest' do

    subject { UserNotifications.digest(user) }

    context "without new topics" do

      it "doesn't send the email" do
        expect(subject.to).to be_blank
      end

    end

    context "with topics only from new users" do
      let!(:new_today)     { Fabricate(:topic, user: Fabricate(:user, trust_level: TrustLevel[0], created_at: 10.minutes.ago), title: "Hey everyone look at me") }
      let!(:new_yesterday) { Fabricate(:topic, user: Fabricate(:user, trust_level: TrustLevel[0], created_at: 25.hours.ago), created_at: 25.hours.ago, title: "This topic is of interest to you") }

      it "returns topics from new users if they're more than 24 hours old" do
        expect(subject.to).to eq([user.email])
        html = subject.html_part.body.to_s
        expect(html).to include(new_yesterday.title)
        expect(html).to_not include(new_today.title)
      end
    end

    context "with new topics" do

      before do
        Fabricate(:topic, user: Fabricate(:coding_horror), created_at: 1.hour.ago)
      end

      it "works" do
        expect(subject.to).to eq([user.email])
        expect(subject.subject).to be_present
        expect(subject.from).to eq([SiteSetting.notification_email])
        expect(subject.html_part.body.to_s).to be_present
        expect(subject.text_part.body.to_s).to be_present
        expect(subject.header["List-Unsubscribe"].to_s).to match(/\/email\/unsubscribe\/\h{64}/)
      end

      it "includes email_prefix in email subject instead of site title" do
        SiteSetting.email_prefix = "Try Discourse"
        SiteSetting.title = "Discourse Meta"

        expect(subject.subject).to match(/Try Discourse/)
        expect(subject.subject).not_to match(/Discourse Meta/)
      end

      it "excludes deleted topics and their posts" do
        deleted = Fabricate(:topic, user: Fabricate(:user), title: "Delete this topic plz", created_at: 1.hour.ago)
        post = Fabricate(:post, topic: deleted, score: 100.0, post_number: 2, raw: "Your wish is my command", created_at: 1.hour.ago)
        deleted.trash!
        html = subject.html_part.body.to_s
        expect(html).to_not include deleted.title
        expect(html).to_not include post.raw
      end

      it "excludes whispers and other post types that don't belong" do
        t = Fabricate(:topic, user: Fabricate(:user), title: "Who likes the same stuff I like?", created_at: 1.hour.ago)
        whisper = Fabricate(:post, topic: t, score: 100.0, post_number: 2, raw: "You like weird stuff", post_type: Post.types[:whisper], created_at: 1.hour.ago)
        mod_action = Fabricate(:post, topic: t, score: 100.0, post_number: 3, raw: "This topic unlisted", post_type: Post.types[:moderator_action], created_at: 1.hour.ago)
        small_action = Fabricate(:post, topic: t, score: 100.0, post_number: 4, raw: "A small action", post_type: Post.types[:small_action], created_at: 1.hour.ago)
        html = subject.html_part.body.to_s
        expect(html).to_not include whisper.raw
        expect(html).to_not include mod_action.raw
        expect(html).to_not include small_action.raw
      end

      it "excludes deleted and hidden posts" do
        t = Fabricate(:topic, user: Fabricate(:user), title: "Post objectionable stuff here", created_at: 1.hour.ago)
        deleted = Fabricate(:post, topic: t, score: 100.0, post_number: 2, raw: "This post is uncalled for", deleted_at: 5.minutes.ago, created_at: 1.hour.ago)
        hidden = Fabricate(:post, topic: t, score: 100.0, post_number: 3, raw: "Try to find this post", hidden: true, hidden_at: 5.minutes.ago, hidden_reason_id: Post.hidden_reasons[:flagged_by_tl3_user], created_at: 1.hour.ago)
        user_deleted = Fabricate(:post, topic: t, score: 100.0, post_number: 4, raw: "I regret this post", user_deleted: true, created_at: 1.hour.ago)
        html = subject.html_part.body.to_s
        expect(html).to_not include deleted.raw
        expect(html).to_not include hidden.raw
        expect(html).to_not include user_deleted.raw
      end

      it "excludes posts that are newer than editing grace period" do
        SiteSetting.editing_grace_period = 5.minutes
        too_new = Fabricate(:topic, user: Fabricate(:user), title: "Oops I need to edit this", created_at: 1.minute.ago)
        too_new_post = Fabricate(:post, user: too_new.user, topic: too_new, score: 100.0, post_number: 1, created_at: 1.minute.ago)
        html = subject.html_part.body.to_s
        expect(html).to_not include too_new.title
      end

      it "uses theme color" do
        cs = Fabricate(:color_scheme, name: 'Fancy', color_scheme_colors: [
          Fabricate(:color_scheme_color, name: 'header_primary',  hex: 'F0F0F0'),
          Fabricate(:color_scheme_color, name: 'header_background', hex: '1E1E1E'),
          Fabricate(:color_scheme_color, name: 'tertiary', hex: '858585')
        ])
        theme = Theme.create!(
          name: 'my name',
          user_id: Fabricate(:admin).id,
          user_selectable: true,
          color_scheme_id: cs.id
        )
        theme.set_default!

        html = subject.html_part.body.to_s
        expect(html).to include 'F0F0F0'
        expect(html).to include '1E1E1E'
        expect(html).to include '858585'
      end
    end

  end

  describe '.user_replied' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe") }
    let(:category) { Fabricate(:category, name: 'India') }
    let(:topic) { Fabricate(:topic, category: category) }
    let(:post) { Fabricate(:post, topic: topic, raw: 'This is My super duper cool topic') }
    let(:response) { Fabricate(:post, reply_to_post_number: 1, topic: post.topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do

      # Fabricator is not fabricating this ...
      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )
      # from should include full user name
      expect(mail[:from].display_names).to eql(['John Doe'])

      # subject should include category name
      expect(mail.subject).to match(/India/)

      mail_html = mail.html_part.to_s

      expect(mail_html.scan(/My super duper cool topic/).count).to eq(1)
      expect(mail_html.scan(/In Reply To/).count).to eq(1)

      # 2 "visit topic" link
      expect(mail_html.scan(/Visit Topic/).count).to eq(2)

      # 2 respond to links cause we have 1 context post
      expect(mail_html.scan(/to respond/).count).to eq(2)

      # 1 unsubscribe
      expect(mail_html.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)

      # no In Reply To if user opts out
      response.user.user_option.email_in_reply_to = false
      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )

      expect(mail.html_part.to_s.scan(/In Reply To/).count).to eq(0)

      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      SiteSetting.prioritize_username_in_ux = false

      response.user.username = "bobmarley"
      response.user.name = "Bob Marley"
      response.user.save

      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )

      mail_html = mail.html_part.to_s
      expect(mail_html.scan(/>Bob Marley/).count).to eq(1)
      expect(mail_html.scan(/>bobmarley/).count).to eq(0)

      SiteSetting.prioritize_username_in_ux = true

      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )

      mail_html = mail.html_part.to_s
      expect(mail_html.scan(/>Bob Marley/).count).to eq(0)
      expect(mail_html.scan(/>bobmarley/).count).to eq(1)
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail = UserNotifications.user_replied(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      expect(mail.html_part.to_s).to_not include(response.raw)
      expect(mail.html_part.to_s).to_not include(topic.url)
      expect(mail.text_part.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(topic.url)
    end
  end

  describe '.user_posted' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe", username: "john") }
    let(:post) { Fabricate(:post) }
    let(:response) { Fabricate(:post, topic: post.topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user, data: { original_username: response_by_user.username }.to_json) }

    it 'generates a correct email' do
      SiteSetting.enable_names = false
      mail = UserNotifications.user_posted(response.user,
                                           post: response,
                                           notification_type: notification.notification_type,
                                           notification_data_hash: notification.data_hash
                                          )

      # from should not include full user name if "show user full names" is disabled
      expect(mail[:from].display_names).to_not eql(['John Doe'])

      # from should include username if "show user full names" is disabled
      expect(mail[:from].display_names).to eql(['john'])

      # subject should not include category name
      expect(mail.subject).not_to match(/Uncategorized/)

      # 1 respond to links as no context by default
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail = UserNotifications.user_posted(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      expect(mail.html_part.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(response.raw)
    end
  end

  describe '.user_private_message' do
    let(:response_by_user) { Fabricate(:user, name: "", username: "john") }
    let(:topic) { Fabricate(:private_message_topic) }
    let(:response) { Fabricate(:post, topic: topic, user: response_by_user) }
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user, data: { original_username: response_by_user.username }.to_json) }

    it 'generates a correct email' do
      SiteSetting.enable_names = true
      mail = UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      # from should include username if full user name is not provided
      expect(mail[:from].display_names).to eql(['john'])

      # subject should include "[PM]"
      expect(mail.subject).to include("[PM] ")

      # 1 "visit message" link
      expect(mail.html_part.to_s.scan(/Visit Message/).count).to eq(1)

      # 1 respond to link
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(topic.id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end

    it "doesn't include details when private_email is enabled" do
      SiteSetting.private_email = true
      mail = UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      expect(mail.html_part.to_s).to_not include(response.raw)
      expect(mail.html_part.to_s).to_not include(topic.url)
      expect(mail.text_part.to_s).to_not include(response.raw)
      expect(mail.text_part.to_s).to_not include(topic.url)
    end

    it "doesn't include group name in subject" do
      group = Fabricate(:group)
      topic.allowed_groups = [ group ]
      mail = UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      expect(mail.subject).to include("[PM] ")
    end

    it "includes a list of participants, groups first with member lists" do
      group1 = Fabricate(:group, name: "group1")
      group2 = Fabricate(:group, name: "group2")

      user1 = Fabricate(:user, username: "one", groups: [group1, group2])
      user2 = Fabricate(:user, username: "two", groups: [group1])

      topic.allowed_users = [user1, user2]
      topic.allowed_groups = [group1, group2]

      mail = UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      expect(mail.body).to include("[group1 (2)](http://test.localhost/groups/group1), [group2 (1)](http://test.localhost/groups/group2), [one](http://test.localhost/u/one), [two](http://test.localhost/u/two)")
    end

    context "when SiteSetting.group_name_in_subject is true" do
      before do
        SiteSetting.group_in_subject = true
      end

      let(:group) { Fabricate(:group, name: "my_group") }
      let(:mail) { UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      ) }

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

      context "one group in pm" do
        before do
          topic.allowed_groups = [ group ]
        end

        include_examples "includes first group name"
      end

      context "multiple groups in pm" do
        let(:group2) { Fabricate(:group) }

        before do
          topic.allowed_groups = [ group, group2 ]
        end

        include_examples "includes first group name"
      end

      context "no groups in pm" do
        it "includes %{optional_pm} in subject" do
          expect(mail.subject).to include("[PM] ")
        end
      end
    end
  end

  it 'adds a warning when mail limit is reached' do
    SiteSetting.max_emails_per_day_per_user = 2
    user = Fabricate(:user)
    user.email_logs.create(email_type: 'blah', to_address: user.email, user_id: user.id, skipped: false)

    post = Fabricate(:post)
    reply = Fabricate(:post, topic_id: post.topic_id)

    notification = Fabricate(:notification, topic_id: post.topic_id, post_number: reply.post_number,
                                            user: post.user, data: { original_username: 'bob' }.to_json)

    mail = UserNotifications.user_replied(
      user,
      post: reply,
      notification_type: notification.notification_type,
      notification_data_hash: notification.data_hash
    )

    # WARNING: you reached the limit of 100 email notifications per day. Further emails will be suppressed.
    # Consider watching less topics or disabling mailing list mode.
    expect(mail.html_part.to_s).to match(I18n.t("user_notifications.reached_limit", count: 2))
    expect(mail.body.to_s).to match(I18n.t("user_notifications.reached_limit", count: 2))
  end

  def expects_build_with(condition)
    UserNotifications.any_instance.expects(:build_email).with(user.email, condition)
    mailer = UserNotifications.send(mail_type, user,
                                    notification_type: Notification.types[notification.notification_type],
                                    notification_data_hash: notification.data_hash,
                                    post: notification.post)
    mailer.message
  end

  shared_examples "supports reply by email" do
    context "reply_by_email" do
      it "should have allow_reply_by_email set when that feature is enabled" do
        expects_build_with(has_entry(:allow_reply_by_email, true))
      end
    end
  end

  shared_examples "no reply by email" do
    context "reply_by_email" do
      it "doesn't support reply by email" do
        expects_build_with(Not(has_entry(:allow_reply_by_email, true)))
      end
    end
  end

  shared_examples "respect for private_email" do
    context "private_email" do
      it "doesn't support reply by email" do
        SiteSetting.private_email = true
        mailer = UserNotifications.send(
          mail_type,
          user,
          notification_type: Notification.types[notification.notification_type],
          notification_data_hash: notification.data_hash,
          post: notification.post
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
    context "set locale for translating templates" do
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
      Fabricate(:notification,
                user: user,
                topic: post.topic,
                notification_type: Notification.types[notification_type],
                post_number: post.post_number,
                data: { original_username: username }.to_json)
    end

    describe 'email building' do
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
        expects_build_with(has_entry(:from_alias, "#{user.name}"))
      end

      it "should not have user name as from_alias if display_name_on_posts is disabled" do
        SiteSetting.enable_names = false
        SiteSetting.display_name_on_posts = false
        expects_build_with(has_entry(:from_alias, "walterwhite"))
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
          body = <<~BODY
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
            "en",
            "#{mail_template}.text_body_template",
            custom_body
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
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_topic }
      include_examples "respect for private_email"
      include_examples "no reply by email"
      include_examples "sets user locale"
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
  shared_examples "notification derived from template" do
    let(:user) { Fabricate(:user, locale: locale) }
    let(:mail_type) { mail_type }
    let(:notification) { Fabricate(:notification, user: user) }
  end

  describe "notifications from template" do

    context "user locale has been set" do

      %w(signup signup_after_approval confirm_old_email notify_old_email confirm_new_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { "fr" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, "fr"))
          end
        end
      end
    end

    context "user locale has not been set" do
      %w(signup signup_after_approval notify_old_email confirm_old_email confirm_new_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { nil }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, nil))
          end
        end
      end
    end

    context "user locale is an empty string" do
      %w(signup signup_after_approval notify_old_email confirm_new_email confirm_old_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { "" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, nil))
          end
        end
      end
    end

  end
end
