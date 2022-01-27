# frozen_string_literal: true

require 'rails_helper'

describe UsernameChanger do
  before do
    Jobs.run_immediately!
  end

  describe '#change' do
    let(:user) { Fabricate(:user) }

    context 'success' do
      let!(:old_username) { user.username }

      it 'should change the username' do
        new_username = "#{user.username}1234"

        events = DiscourseEvent.track_events {
          @result = UsernameChanger.change(user, new_username)
        }.last(2)

        expect(@result).to eq(true)

        event = events.first
        expect(event[:event_name]).to eq(:username_changed)
        expect(event[:params].first).to eq(old_username)
        expect(event[:params].second).to eq(new_username)

        event = events.last
        expect(event[:event_name]).to eq(:user_updated)
        expect(event[:params].first).to eq(user)

        user.reload
        expect(user.username).to eq(new_username)
        expect(user.username_lower).to eq(new_username.downcase)
      end

      it 'do nothing if the new username is the same' do
        new_username = user.username

        events = DiscourseEvent.track_events {
          @result = UsernameChanger.change(user, new_username)
        }

        expect(@result).to eq(false)
        expect(events.count).to be_zero
      end
    end

    context 'failure' do
      let(:wrong_username) { "" }
      let(:username_before_change) { user.username }
      let(:username_lower_before_change) { user.username_lower }

      it 'should not change the username' do
        @result = UsernameChanger.change(user, wrong_username)
        expect(@result).to eq(false)

        user.reload
        expect(user.username).to eq(username_before_change)
        expect(user.username_lower).to eq(username_lower_before_change)
      end
    end

    describe 'change the case of my username' do
      let!(:myself) { Fabricate(:user, username: 'hansolo') }

      it 'should change the username' do
        expect do
          expect(UsernameChanger.change(myself, "HanSolo", myself)).to eq(true)
        end.to change { UserHistory.count }.by(1)

        expect(UserHistory.last.action).to eq(
          UserHistory.actions[:change_username]
        )

        expect(myself.reload.username).to eq('HanSolo')

        expect do
          UsernameChanger.change(myself, "HanSolo", myself)
        end.to change { UserHistory.count }.by(0) # make sure it does not log a dupe

        expect do
          UsernameChanger.change(myself, user.username, myself)
        end.to change { UserHistory.count }.by(0) # does not log if the username already exists
      end
    end

    describe 'allow custom minimum username length from site settings' do
      before do
        @custom_min = 2
        SiteSetting.min_username_length = @custom_min
      end

      it 'should allow a shorter username than default' do
        result = UsernameChanger.change(user, 'a' * @custom_min)
        expect(result).not_to eq(false)
      end

      it 'should not allow a shorter username than limit' do
        result = UsernameChanger.change(user, 'a' * (@custom_min - 1))
        expect(result).to eq(false)
      end

      it 'should not allow a longer username than limit' do
        result = UsernameChanger.change(user, 'a' * (User.username_length.end + 1))
        expect(result).to eq(false)
      end
    end

    context 'posts and revisions' do
      let(:user) { Fabricate(:user, username: 'foo') }
      let(:topic) { Fabricate(:topic, user: user) }

      before do
        UserActionManager.enable
        Discourse.expects(:warn_exception).never
      end

      def create_post_and_change_username(args = {}, &block)
        stub_image_size
        post = create_post(args.merge(topic_id: topic.id))

        args.delete(:revisions)&.each do |revision|
          post.revise(post.user, revision, force_new_version: true)
        end

        block.call(post) if block

        UsernameChanger.change(user, args[:target_username] || 'bar')
        post.reload
      end

      context 'mentions' do
        it 'rewrites cooked correctly' do
          post = create_post_and_change_username(raw: "Hello @foo")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))

          post.rebake!
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'removes the username from the search index' do
          SearchIndexer.enable
          create_post_and_change_username(raw: "Hello @foo")

          results = Search.execute('foo', min_search_term_length: 1)
          expect(results.posts).to be_empty
        end

        it 'ignores case when replacing mentions' do
          post = create_post_and_change_username(raw: "There's no difference between @foo and @Foo")

          expect(post.raw).to eq("There's no difference between @bar and @bar")
          expect(post.cooked).to eq(%Q(<p>There’s no difference between <a class="mention" href="/u/bar">@bar</a> and <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'replaces mentions when there are leading symbols' do
          post = create_post_and_change_username(raw: ".@foo -@foo %@foo _@foo ,@foo ;@foo @@foo")

          expect(post.raw).to eq(".@bar -@bar %@bar _@bar ,@bar ;@bar @@bar")
          expect(post.cooked).to match_html <<~HTML
            <p>.<a class="mention" href="/u/bar">@bar</a>
               -<a class="mention" href="/u/bar">@bar</a>
               %<a class="mention" href="/u/bar">@bar</a>
               _<a class="mention" href="/u/bar">@bar</a>
               ,<a class="mention" href="/u/bar">@bar</a>
               ;<a class="mention" href="/u/bar">@bar</a>
               @<a class="mention" href="/u/bar">@bar</a></p>
          HTML
        end

        it 'replaces mentions within double and single quotes' do
          post = create_post_and_change_username(raw: %Q("@foo" '@foo'))

          expect(post.raw).to eq(%Q("@bar" '@bar'))
          expect(post.cooked).to eq(%Q(<p>“<a class="mention" href="/u/bar">@bar</a>” ‘<a class="mention" href="/u/bar">@bar</a>’</p>))
        end

        it 'replaces Markdown formatted mentions' do
          post = create_post_and_change_username(raw: "**@foo** *@foo* _@foo_ ~~@foo~~")

          expect(post.raw).to eq("**@bar** *@bar* _@bar_ ~~@bar~~")
          expect(post.cooked).to match_html <<~HTML
            <p><strong><a class="mention" href="/u/bar">@bar</a></strong>
               <em><a class="mention" href="/u/bar">@bar</a></em>
               <em><a class="mention" href="/u/bar">@bar</a></em>
               <s><a class="mention" href="/u/bar">@bar</a></s></p>
          HTML
        end

        it 'replaces mentions when there are trailing symbols' do
          post = create_post_and_change_username(raw: "@foo. @foo, @foo: @foo; @foo_ @foo-")

          expect(post.raw).to eq("@bar. @bar, @bar: @bar; @bar_ @bar-")
          expect(post.cooked).to match_html <<~HTML
            <p><a class="mention" href="/u/bar">@bar</a>.
               <a class="mention" href="/u/bar">@bar</a>,
               <a class="mention" href="/u/bar">@bar</a>:
               <a class="mention" href="/u/bar">@bar</a>;
               <a class="mention" href="/u/bar">@bar</a>_
               <a class="mention" href="/u/bar">@bar</a>-</p>
          HTML
        end

        it 'does not replace mention in cooked when mention contains a trailing underscore' do
          # Older versions of Discourse detected a trailing underscore as part of a username.
          # That doesn't happen anymore, so we need to do create the `cooked` for this test manually.
          post = create_post_and_change_username(raw: "@foobar @foo") do |p|
            p.update_columns(raw: p.raw.gsub("@foobar", "@foo_"), cooked: p.cooked.gsub("@foobar", "@foo_"))
          end

          expect(post.raw).to eq("@bar_ @bar")
          expect(post.cooked).to eq(%Q(<p><span class="mention">@foo_</span> <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'does not replace mentions when there are leading alphanumeric chars' do
          post = create_post_and_change_username(raw: "@foo a@foo 2@foo")

          expect(post.raw).to eq("@bar a@foo 2@foo")
          expect(post.cooked).to eq(%Q(<p><a class="mention" href="/u/bar">@bar</a> a@foo 2@foo</p>))
        end

        it 'does not replace username within email address' do
          post = create_post_and_change_username(raw: "@foo mail@foo.com")

          expect(post.raw).to eq("@bar mail@foo.com")
          expect(post.cooked).to eq(%Q(<p><a class="mention" href="/u/bar">@bar</a> <a href="mailto:mail@foo.com">mail@foo.com</a></p>))
        end

        it 'does not replace username in a mention of a similar username' do
          Fabricate(:user, username: 'foobar')
          Fabricate(:user, username: 'foo-bar')
          Fabricate(:user, username: 'foo_bar')
          Fabricate(:user, username: 'foo1')

          post = create_post_and_change_username(raw: "@foo @foobar @foo-bar @foo_bar @foo1")

          expect(post.raw).to eq("@bar @foobar @foo-bar @foo_bar @foo1")
          expect(post.cooked).to match_html <<~HTML
            <p><a class="mention" href="/u/bar">@bar</a> <a class="mention" href="/u/foobar">@foobar</a> <a class="mention" href="/u/foo-bar">@foo-bar</a> <a class="mention" href="/u/foo_bar">@foo_bar</a> <a class="mention" href="/u/foo1">@foo1</a></p>
          HTML
        end

        it 'updates the path to the user even when it links to /user instead of /u' do
          post = create_post_and_change_username(raw: "Hello @foo")
          post.update_column(:cooked, post.cooked.gsub("/u/foo", "/users/foo"))

          expect(post.raw).to eq("Hello @bar")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'replaces mentions within revisions' do
          revisions = [{ raw: "Hello Foo" }, { title: "new topic title" }, { raw: "Hello @foo!" }, { raw: "Hello @foo!!" }]
          post = create_post_and_change_username(raw: "Hello @foo", revisions: revisions)

          expect(post.raw).to eq("Hello @bar!!")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!!</p>))

          expect(post.revisions.count).to eq(4)

          expect(post.revisions[0].modifications["raw"][0]).to eq("Hello @bar")
          expect(post.revisions[0].modifications["raw"][1]).to eq("Hello Foo")
          expect(post.revisions[0].modifications["cooked"][0]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
          expect(post.revisions[0].modifications["cooked"][1]).to eq(%Q(<p>Hello Foo</p>))

          expect(post.revisions[1].modifications).to include("title")

          expect(post.revisions[2].modifications["raw"][0]).to eq("Hello Foo")
          expect(post.revisions[2].modifications["raw"][1]).to eq("Hello @bar!")
          expect(post.revisions[2].modifications["cooked"][0]).to eq(%Q(<p>Hello Foo</p>))
          expect(post.revisions[2].modifications["cooked"][1]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!</p>))

          expect(post.revisions[3].modifications["raw"][0]).to eq("Hello @bar!")
          expect(post.revisions[3].modifications["raw"][1]).to eq("Hello @bar!!")
          expect(post.revisions[3].modifications["cooked"][0]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!</p>))
          expect(post.revisions[3].modifications["cooked"][1]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!!</p>))
        end

        it 'replaces mentions in posts marked for deletion' do
          post = create_post_and_change_username(raw: "Hello @foo") do |p|
            PostDestroyer.new(p.user, p).destroy
          end

          expect(post.raw).to_not include("@foo")
          expect(post.cooked).to_not include("foo")
          expect(post.revisions.count).to eq(1)

          expect(post.revisions[0].modifications["raw"][0]).to eq("Hello @bar")
          expect(post.revisions[0].modifications["cooked"][0]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'works when users are mentioned with HTML' do
          post = create_post_and_change_username(raw: '<a class="mention">@foo</a> and <a class="mention">@someuser</a>')

          expect(post.raw).to eq('<a class="mention">@bar</a> and <a class="mention">@someuser</a>')
          expect(post.cooked).to match_html('<p><a class="mention">@bar</a> and <a class="mention">@someuser</a></p>')
        end

        context "Unicode usernames" do
          before { SiteSetting.unicode_usernames = true }
          let(:user) { Fabricate(:user, username: 'թռչուն') }

          it 'it correctly updates mentions' do
            post = create_post_and_change_username(raw: "Hello @թռչուն", target_username: 'птица')

            expect(post.raw).to eq("Hello @птица")
            expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/%D0%BF%D1%82%D0%B8%D1%86%D0%B0">@птица</a></p>))
          end

          it 'does not replace mentions when there are leading alphanumeric chars' do
            post = create_post_and_change_username(raw: "Hello @թռչուն 鳥@թռչուն 2@թռչուն ٩@թռչուն", target_username: 'птица')

            expect(post.raw).to eq("Hello @птица 鳥@թռչուն 2@թռչուն ٩@թռչուն")
            expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/%D0%BF%D1%82%D0%B8%D1%86%D0%B0">@птица</a> 鳥@թռչուն 2@թռչուն ٩@թռչուն</p>))
          end

          it 'does not replace username in a mention of a similar username' do
            Fabricate(:user, username: 'թռչուն鳥')
            Fabricate(:user, username: 'թռչուն-鳥')
            Fabricate(:user, username: 'թռչուն_鳥')
            Fabricate(:user, username: 'թռչուն٩')

            post = create_post_and_change_username(raw: "@թռչուն @թռչուն鳥 @թռչուն-鳥 @թռչուն_鳥 @թռչուն٩", target_username: 'птица')

            expect(post.raw).to eq("@птица @թռչուն鳥 @թռչուն-鳥 @թռչուն_鳥 @թռչուն٩")
            expect(post.cooked).to match_html <<~HTML
              <p><a class="mention" href="/u/%D0%BF%D1%82%D0%B8%D1%86%D0%B0">@птица</a> <a class="mention" href="/u/%D5%A9%D5%BC%D5%B9%D5%B8%D6%82%D5%B6%E9%B3%A5">@թռչուն鳥</a> <a class="mention" href="/u/%D5%A9%D5%BC%D5%B9%D5%B8%D6%82%D5%B6-%E9%B3%A5">@թռչուն-鳥</a> <a class="mention" href="/u/%D5%A9%D5%BC%D5%B9%D5%B8%D6%82%D5%B6_%E9%B3%A5">@թռչուն_鳥</a> <a class="mention" href="/u/%D5%A9%D5%BC%D5%B9%D5%B8%D6%82%D5%B6%D9%A9">@թռչուն٩</a></p>
            HTML
          end

        end
      end

      context 'quotes' do
        let(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
        let(:avatar_url) { user.avatar_template_url.gsub("{size}", "40") }

        it 'replaces the username in quote tags and updates avatar' do
          post = create_post_and_change_username(raw: <<~RAW)
            Lorem ipsum

            [quote="foo, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]

            [quote='foo']
            quoted post
            [/quote]

            [quote=foo, post:1, topic:#{quoted_post.topic.id}]
            quoted post
            [/quote]

            dolor sit amet
          RAW

          expect(post.raw).to eq(<<~RAW.strip)
            Lorem ipsum

            [quote="bar, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]

            [quote='bar']
            quoted post
            [/quote]

            [quote=bar, post:1, topic:#{quoted_post.topic.id}]
            quoted post
            [/quote]

            dolor sit amet
          RAW

          expect(post.cooked).to match_html <<~HTML
            <p>Lorem ipsum</p>
            <aside class="quote no-group" data-username="bar" data-post="1" data-topic="#{quoted_post.topic.id}">
            <div class="title">
            <div class="quote-controls"></div>
            <img loading="lazy" alt='' width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <aside class="quote no-group" data-username="bar">
            <div class="title">
            <div class="quote-controls"></div>
            <img loading="lazy" alt="" width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <aside class="quote no-group" data-username="bar" data-post="1" data-topic="#{quoted_post.topic.id}">
            <div class="title">
            <div class="quote-controls"></div>
            <img loading="lazy" alt="" width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <p>dolor sit amet</p>
          HTML
        end

        context 'simple quote' do
          let(:raw) do <<~RAW
              Lorem ipsum

              [quote="foo, post:1, topic:#{quoted_post.topic.id}"]
              quoted
              [/quote]
            RAW
          end

          let(:expected_raw) do
            <<~RAW.strip
              Lorem ipsum

              [quote="bar, post:1, topic:#{quoted_post.topic.id}"]
              quoted
              [/quote]
            RAW
          end

          let(:expected_cooked) do
            <<~HTML.rstrip
              <p>Lorem ipsum</p>
              <aside class="quote no-group" data-username="bar" data-post="1" data-topic="#{quoted_post.topic.id}">
              <div class="title">
              <div class="quote-controls"></div>
              <img loading="lazy" alt='' width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
              <blockquote>
              <p>quoted</p>
              </blockquote>
              </aside>
            HTML
          end

          it 'replaces the username in quote tags when the post is deleted' do
            post = create_post_and_change_username(raw: raw) do |p|
              PostDestroyer.new(Discourse.system_user, p).destroy
            end

            expect(post.raw).to eq(expected_raw)
            expect(post.cooked).to match_html(expected_cooked)
          end
        end
      end

      context 'oneboxes' do
        let(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
        let(:avatar_url) { user_avatar_url(user) }
        let(:evil_trout) { Fabricate(:evil_trout) }
        let(:another_quoted_post) { create_post(user: evil_trout, topic: topic, post_number: 2, raw: "evil post") }

        def protocol_relative_url(url)
          url.sub(/^https?:/, '')
        end

        def user_avatar_url(u)
          u.avatar_template_url.gsub("{size}", "40")
        end

        it 'updates avatar for linked topics and posts' do
          raw = "#{quoted_post.full_url}\n#{quoted_post.topic.url}"
          post = create_post_and_change_username(raw: raw)

          expect(post.raw).to eq(raw)
          expect(post.cooked).to match_html <<~HTML
            <aside class="quote" data-post="#{quoted_post.post_number}" data-topic="#{quoted_post.topic.id}">
              <div class="title">
                <div class="quote-controls"></div>
                <img loading="lazy" alt="" width="20" height="20" src="#{avatar_url}" class="avatar">
                <a href="#{protocol_relative_url(quoted_post.full_url)}">#{quoted_post.topic.title}</a>
              </div>
              <blockquote>
                quoted post
              </blockquote>
            </aside>

            <aside class="quote" data-post="#{quoted_post.post_number}" data-topic="#{quoted_post.topic.id}">
              <div class="title">
                <div class="quote-controls"></div>
                <img loading="lazy" alt="" width="20" height="20" src="#{avatar_url}" class="avatar">
                <a href="#{protocol_relative_url(quoted_post.topic.url)}">#{quoted_post.topic.title}</a>
              </div>
              <blockquote>
                quoted post
              </blockquote>
            </aside>
          HTML
        end

        it 'does not update the wrong avatar' do
          raw = "#{quoted_post.full_url}\n#{another_quoted_post.full_url}"
          post = create_post_and_change_username(raw: raw)

          expect(post.raw).to eq(raw)
          expect(post.cooked).to match_html <<~HTML
            <aside class="quote" data-post="#{quoted_post.post_number}" data-topic="#{quoted_post.topic.id}">
              <div class="title">
                <div class="quote-controls"></div>
                <img loading="lazy" alt="" width="20" height="20" src="#{avatar_url}" class="avatar">
                <a href="#{protocol_relative_url(quoted_post.full_url)}">#{quoted_post.topic.title}</a>
              </div>
              <blockquote>
                quoted post
              </blockquote>
            </aside>

            <aside class="quote" data-post="#{another_quoted_post.post_number}" data-topic="#{another_quoted_post.topic.id}">
              <div class="title">
                <div class="quote-controls"></div>
                <img loading="lazy" alt="" width="20" height="20" src="#{user_avatar_url(evil_trout)}" class="avatar">
                <a href="#{protocol_relative_url(another_quoted_post.full_url)}">#{another_quoted_post.topic.title}</a>
              </div>
              <blockquote>
                evil post
              </blockquote>
            </aside>
          HTML
        end
      end

      it 'updates username in small action posts' do
        invited_by = Fabricate(:user)
        p1 = topic.add_small_action(invited_by, 'invited_user', 'foo')
        p2 = topic.add_small_action(invited_by, 'invited_user', 'foobar')
        UsernameChanger.change(user, 'bar')

        expect(p1.reload.custom_fields['action_code_who']).to eq('bar')
        expect(p2.reload.custom_fields['action_code_who']).to eq('foobar')
      end
    end

    context 'notifications' do
      def create_notification(type, notified_user, post, data = {})
        Fabricate(
          :notification,
          notification_type: Notification.types[type],
          user: notified_user,
          data: data.to_json,
          topic: post&.topic,
          post_number: post&.post_number
        )
      end

      def notification_data(notification)
        JSON.parse(notification.reload.data, symbolize_names: true)
      end

      def original_and_display_username(username)
        { original_username: username, display_username: username, foo: "bar" }
      end

      def original_username_and_some_text_as_display_username(username)
        { original_username: username, display_username: "some text", foo: "bar" }
      end

      def only_display_username(username)
        { display_username: username }
      end

      def username_and_something_else(username)
        { username: username, foo: "bar" }
      end

      it 'replaces usernames in notifications' do
        renamed_user = Fabricate(:user, username: "alice")
        another_user = Fabricate(:user, username: "another_user")
        notified_user = Fabricate(:user)
        p1 = Fabricate(:post, post_number: 1, user: renamed_user)
        p2 = Fabricate(:post, post_number: 1, user: another_user)
        Fabricate(:invited_user, invite: Fabricate(:invite, invited_by: notified_user), user: renamed_user)
        Fabricate(:invited_user, invite: Fabricate(:invite, invited_by: notified_user), user: another_user)

        n01 = create_notification(:mentioned, notified_user, p1, original_and_display_username("alice"))
        n02 = create_notification(:mentioned, notified_user, p2, original_and_display_username("another_user"))
        n03 = create_notification(:mentioned, notified_user, p1, original_username_and_some_text_as_display_username("alice"))
        n04 = create_notification(:mentioned, notified_user, p1, only_display_username("alice"))
        n05 = create_notification(:invitee_accepted, notified_user, nil, only_display_username("alice"))
        n06 = create_notification(:invitee_accepted, notified_user, nil, only_display_username("another_user"))
        n07 = create_notification(:granted_badge, renamed_user, nil, username_and_something_else("alice"))
        n08 = create_notification(:granted_badge, another_user, nil, username_and_something_else("another_user"))
        n09 = create_notification(:group_message_summary, renamed_user, nil, username_and_something_else("alice"))
        n10 = create_notification(:group_message_summary, another_user, nil, username_and_something_else("another_user"))

        UsernameChanger.change(renamed_user, "bob")

        expect(notification_data(n01)).to eq(original_and_display_username("bob"))
        expect(notification_data(n02)).to eq(original_and_display_username("another_user"))
        expect(notification_data(n03)).to eq(original_username_and_some_text_as_display_username("bob"))
        expect(notification_data(n04)).to eq(only_display_username("bob"))
        expect(notification_data(n05)).to eq(only_display_username("bob"))
        expect(notification_data(n06)).to eq(only_display_username("another_user"))
        expect(notification_data(n07)).to eq(username_and_something_else("bob"))
        expect(notification_data(n08)).to eq(username_and_something_else("another_user"))
        expect(notification_data(n09)).to eq(username_and_something_else("bob"))
        expect(notification_data(n10)).to eq(username_and_something_else("another_user"))
      end
    end
  end

  describe '#override' do
    common_test_cases = [
      [
        "overrides the username if a new name is different",
        "john", "bill", "bill", false
      ],
      [
        "does not change the username if a new name is the same",
        "john", "john", "john", false
      ],
      [
        "overrides the username if a new name has different case",
        "john", "JoHN", "JoHN", false
      ]
    ]

    context "unicode_usernames is off" do
      before do
        SiteSetting.unicode_usernames = false
      end

      [
        *common_test_cases,
        [
          "does not change the username if a new name after unicode normalization is the same",
          "john", "john¥¥", "john"
        ],
      ].each do |testcase_name, current, new, overrode|
        it "#{testcase_name}" do
          user = Fabricate(:user, username: current)
          UsernameChanger.override(user, new)
          expect(user.username).to eq(overrode)
        end
      end

      it "overrides the username with username suggestions in case the username is already taken" do
        user = Fabricate(:user, username: "bill")
        Fabricate(:user, username: "john")

        UsernameChanger.override(user, "john")

        expect(user.username).to eq("john1")
      end
    end

    context "unicode_usernames is on" do
      before do
        SiteSetting.unicode_usernames = true
      end

      [
        *common_test_cases,
        [
          "overrides the username if a new name after unicode normalization is different only in case",
          "lo\u0308we", "L\u00F6wee", "L\u00F6wee"
        ],
      ].each do |testcase_name, current, new, overrode|
        it "#{testcase_name}" do
          user = Fabricate(:user, username: current)
          UsernameChanger.override(user, new)
          expect(user.username).to eq(overrode)
        end
      end
    end
  end

end
