require 'rails_helper'

describe UsernameChanger do

  describe '#change' do
    let(:user) { Fabricate(:user) }

    context 'success' do
      let(:new_username) { "#{user.username}1234" }

      before do
        @result = UsernameChanger.change(user, new_username)
      end

      it 'returns true' do
        expect(@result).to eq(true)
      end

      it 'should change the username' do
        user.reload
        expect(user.username).to eq(new_username)
      end

      it 'should change the username_lower' do
        user.reload
        expect(user.username_lower).to eq(new_username.downcase)
      end
    end

    context 'failure' do
      let(:wrong_username) { "" }
      let(:username_before_change) { user.username }
      let(:username_lower_before_change) { user.username_lower }

      before do
        @result = UsernameChanger.change(user, wrong_username)
      end

      it 'returns false' do
        expect(@result).to eq(false)
      end

      it 'should not change the username' do
        user.reload
        expect(user.username).to eq(username_before_change)
      end

      it 'should not change the username_lower' do
        user.reload
        expect(user.username_lower).to eq(username_lower_before_change)
      end
    end

    describe 'change the case of my username' do
      let!(:myself) { Fabricate(:user, username: 'hansolo') }

      it 'should return true' do
        expect(UsernameChanger.change(myself, "HanSolo")).to eq(true)
      end

      it 'should change the username' do
        UsernameChanger.change(myself, "HanSolo")
        expect(myself.reload.username).to eq('HanSolo')
      end

      it "logs the action" do
        expect { UsernameChanger.change(myself, "HanSolo", myself) }.to change { UserHistory.count }.by(1)
        expect { UsernameChanger.change(myself, "HanSolo", myself) }.to change { UserHistory.count }.by(0) # make sure it does not log a dupe
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

      before { UserActionCreator.enable }
      after { UserActionCreator.disable }

      def create_post_and_change_username(args = {})
        post = create_post(args.merge(topic_id: topic.id))

        args.delete(:revisions)&.each do |revision|
          post.revise(post.user, revision, force_new_version: true)
        end

        UsernameChanger.change(user, 'bar')
        post.reload
      end

      context 'mentions' do
        it 'rewrites cooked correctly' do
          post = create_post_and_change_username(raw: "Hello @foo")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))

          post.rebake!
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'ignores case when replacing mentions' do
          post = create_post_and_change_username(raw: "There's no difference between @foo and @Foo")

          expect(post.raw).to eq("There's no difference between @bar and @bar")
          expect(post.cooked).to eq(%Q(<p>There’s no difference between <a class="mention" href="/u/bar">@bar</a> and <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'replaces mentions when there are leading symbols' do
          post = create_post_and_change_username(raw: ".@foo -@foo %@foo _@foo ,@foo ;@foo @@foo")

          expect(post.raw).to eq(".@bar -@bar %@bar _@bar ,@bar ;@bar @@bar")
          expect(post.cooked).to match_html(<<~HTML)
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

        it 'replaces mentions when there are trailing symbols' do
          post = create_post_and_change_username(raw: "@foo. @foo, @foo: @foo; @foo-")

          expect(post.raw).to eq("@bar. @bar, @bar: @bar; @bar-")
          expect(post.cooked).to match_html(<<~HTML)
          <p><a class="mention" href="/u/bar">@bar</a>.
             <a class="mention" href="/u/bar">@bar</a>,
             <a class="mention" href="/u/bar">@bar</a>:
             <a class="mention" href="/u/bar">@bar</a>;
             <a class="mention" href="/u/bar">@bar</a>-</p>
          HTML
        end

        it 'does not replace mention when followed by an underscore' do
          post = create_post_and_change_username(raw: "@foo_")

          expect(post.raw).to eq("@foo_")
          expect(post.cooked).to eq(%Q(<p><span class="mention">@foo_</span></p>))
        end

        it 'does not replace mentions when there are leading alphanumeric chars' do
          post = create_post_and_change_username(raw: "a@foo 2@foo")

          expect(post.raw).to eq("a@foo 2@foo")
          expect(post.cooked).to eq(%Q(<p>a@foo 2@foo</p>))
        end

        it 'does not replace username within email address' do
          post = create_post_and_change_username(raw: "mail@foo.com")

          expect(post.raw).to eq("mail@foo.com")
          expect(post.cooked).to eq(%Q(<p><a href="mailto:mail@foo.com">mail@foo.com</a></p>))
        end

        it 'does not replace username in a mention of a similar username' do
          Fabricate(:user, username: 'foobar')
          Fabricate(:user, username: 'foo-bar')
          Fabricate(:user, username: 'foo_bar')
          Fabricate(:user, username: 'foo1')

          post = create_post_and_change_username(raw: "@foo @foobar @foo-bar @foo_bar @foo1")

          expect(post.raw).to eq("@bar @foobar @foo-bar @foo_bar @foo1")
          expect(post.cooked).to match_html(<<~HTML)
          <p><a class="mention" href="/u/bar">@bar</a>
             <a class="mention" href="/u/foobar">@foobar</a>
             <a class="mention" href="/u/foo-bar">@foo-bar</a>
             <a class="mention" href="/u/foo_bar">@foo_bar</a>
             <a class="mention" href="/u/foo1">@foo1</a></p>
          HTML
        end

        it 'updates the path to the user even when it links to /user instead of /u' do
          post = create_post_and_change_username(raw: "Hello @foo")
          post.update_column(:cooked, post.cooked.gsub("/u/foo", "/users/foo"))

          expect(post.raw).to eq("Hello @bar")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
        end

        it 'replaces mentions within revisions' do
          revisions = [{ raw: "Hello Foo" }, { raw: "Hello @foo!" }, { raw: "Hello @foo!!" }]
          post = create_post_and_change_username(raw: "Hello @foo", revisions: revisions)

          expect(post.raw).to eq("Hello @bar!!")
          expect(post.cooked).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!!</p>))

          expect(post.revisions.count).to eq(3)

          expect(post.revisions[0].modifications["raw"][0]).to eq("Hello @bar")
          expect(post.revisions[0].modifications["raw"][1]).to eq("Hello Foo")
          expect(post.revisions[0].modifications["cooked"][0]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a></p>))
          expect(post.revisions[0].modifications["cooked"][1]).to eq(%Q(<p>Hello Foo</p>))

          expect(post.revisions[1].modifications["raw"][0]).to eq("Hello Foo")
          expect(post.revisions[1].modifications["raw"][1]).to eq("Hello @bar!")
          expect(post.revisions[1].modifications["cooked"][0]).to eq(%Q(<p>Hello Foo</p>))
          expect(post.revisions[1].modifications["cooked"][1]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!</p>))

          expect(post.revisions[2].modifications["raw"][0]).to eq("Hello @bar!")
          expect(post.revisions[2].modifications["raw"][1]).to eq("Hello @bar!!")
          expect(post.revisions[2].modifications["cooked"][0]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!</p>))
          expect(post.revisions[2].modifications["cooked"][1]).to eq(%Q(<p>Hello <a class="mention" href="/u/bar">@bar</a>!!</p>))
        end
      end

      context 'quotes' do
        let(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }

        it 'replaces the username in quote tags' do
          avatar_url = user.avatar_template_url.gsub("{size}", "40")

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

          expect(post.cooked).to match_html(<<~HTML)
            <p>Lorem ipsum</p>
            <aside class="quote no-group" data-post="1" data-topic="#{quoted_post.topic.id}">
            <div class="title">
            <div class="quote-controls"></div>
            <img alt width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <aside class="quote no-group">
            <div class="title">
            <div class="quote-controls"></div>
            <img alt width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <aside class="quote no-group" data-post="1" data-topic="#{quoted_post.topic.id}">
            <div class="title">
            <div class="quote-controls"></div>
            <img alt width="20" height="20" src="#{avatar_url}" class="avatar"> bar:</div>
            <blockquote>
            <p>quoted post</p>
            </blockquote>
            </aside>
            <p>dolor sit amet</p>
          HTML
        end

        # TODO spec for quotes in revisions
      end
    end

  end

end
