# frozen_string_literal: true

require "pretty_text"

RSpec.describe PrettyText do
  fab!(:user)
  fab!(:post)

  before { SiteSetting.enable_markdown_typographer = false }

  def n(html)
    html.strip
  end

  def cook(*args)
    PrettyText.cook(*args)
  end

  let(:wrapped_image) do
    "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"><div class=\"meta\">\n<span class=\"filename\">Screen Shot 2014-04-14 at 9.47.10 PM.png</span><span class=\"informations\">966x737 1.47 MB</span><span class=\"expand\"></span>\n</div></a></div>"
  end

  describe "Quoting" do
    context "with avatar" do
      let(:default_avatar) do
        "//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png"
      end

      before { User.stubs(:default_template).returns(default_avatar) }

      it "correctly extracts usernames from the new quote format" do
        topic = Fabricate(:topic, title: "this is a test topic :slight_smile:")
        expected = <<~HTML
          <aside class="quote no-group" data-username="codinghorror" data-post="2" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-a-test-topic/#{topic.id}/2">This is a test topic <img width="20" height="20" src="/images/emoji/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title="slight_smile" loading="lazy" alt="slight_smile" class="emoji"></a></div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(
          cook(
            "[quote=\"Jeff, post:2, topic:#{topic.id}, username:codinghorror\"]\nddd\n[/quote]",
            topic_id: 1,
          ),
        ).to eq(n(expected))
      end

      it "do off topic quoting with emoji unescape" do
        topic = Fabricate(:topic, title: "this is a test topic :slight_smile:")
        expected = <<~HTML
          <aside class="quote no-group" data-username="EvilTrout" data-post="2" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-a-test-topic/#{topic.id}/2">This is a test topic <img width="20" height="20" src="/images/emoji/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title="slight_smile" loading="lazy" alt="slight_smile" class="emoji"></a></div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(
          cook("[quote=\"EvilTrout, post:2, topic:#{topic.id}\"]\nddd\n[/quote]", topic_id: 1),
        ).to eq(n(expected))
      end

      context "with emojis" do
        let(:md) { <<~MD }
          > This is a quote with a regular emoji :upside_down_face:

          > This is a quote with an emoji shortcut :)

          > This is a quote with a Unicode emoji 😎
          MD

        it "does not unescape emojis when emojis are disabled" do
          SiteSetting.enable_emoji = false

          html = <<~HTML
            <blockquote>
            <p>This is a quote with a regular emoji :upside_down_face:</p>
            </blockquote>
            <blockquote>
            <p>This is a quote with an emoji shortcut :)</p>
            </blockquote>
            <blockquote>
            <p>This is a quote with a Unicode emoji 😎</p>
            </blockquote>
          HTML

          expect(cook(md)).to eq(html.strip)
        end

        it "does not convert emoji shortcuts when emoji shortcuts are disabled" do
          SiteSetting.enable_emoji_shortcuts = false

          html = <<~HTML
            <blockquote>
            <p>This is a quote with a regular emoji <img src="/images/emoji/twitter/upside_down_face.png?v=#{Emoji::EMOJI_VERSION}" title=":upside_down_face:" class="emoji" alt=":upside_down_face:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with an emoji shortcut :)</p>
            </blockquote>
            <blockquote>
            <p>This is a quote with a Unicode emoji <img src="/images/emoji/twitter/sunglasses.png?v=#{Emoji::EMOJI_VERSION}" title=":sunglasses:" class="emoji" alt=":sunglasses:" loading="lazy" width="20" height="20"></p>
            </blockquote>
          HTML

          expect(cook(md)).to eq(html.strip)
        end

        it "unescapes all emojis" do
          html = <<~HTML
            <blockquote>
            <p>This is a quote with a regular emoji <img src="/images/emoji/twitter/upside_down_face.png?v=#{Emoji::EMOJI_VERSION}" title=":upside_down_face:" class="emoji" alt=":upside_down_face:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with an emoji shortcut <img src="/images/emoji/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with a Unicode emoji <img src="/images/emoji/twitter/sunglasses.png?v=#{Emoji::EMOJI_VERSION}" title=":sunglasses:" class="emoji" alt=":sunglasses:" loading="lazy" width="20" height="20"></p>
            </blockquote>
          HTML

          expect(cook(md)).to eq(html.strip)
        end

        it "adds an only-emoji class when a line has only one emoji" do
          md = <<~MD
            ☹️
            foo 😀
            foo 😀 bar
            :smile_cat:
            :smile_cat: :smile_cat:
            :smile_cat: :smile_cat: :smile_cat: :smile_cat:
            baz? :smile_cat:
            😀
            😉 foo
            😉 😉
             😉 😉
            😉 😉 😉
            😉😉😉
            😉 😉 😉
            😉d😉 😉
            😉 😉 😉d
            😉😉😉😉
          MD

          html = <<~HTML
            <p><img src="/images/emoji/twitter/frowning.png?v=#{Emoji::EMOJI_VERSION}" title=":frowning:" class="emoji only-emoji" alt=":frowning:" loading="lazy" width="20" height="20"><br>
            foo <img src="/images/emoji/twitter/grinning.png?v=#{Emoji::EMOJI_VERSION}" title=":grinning:" class="emoji" alt=":grinning:" loading="lazy" width="20" height="20"><br>
            foo <img src="/images/emoji/twitter/grinning.png?v=#{Emoji::EMOJI_VERSION}" title=":grinning:" class="emoji" alt=":grinning:" loading="lazy" width="20" height="20"> bar<br>
            <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji only-emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji only-emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji only-emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"><br>
            baz? <img src="/images/emoji/twitter/smile_cat.png?v=#{Emoji::EMOJI_VERSION}" title=":smile_cat:" class="emoji" alt=":smile_cat:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/grinning.png?v=#{Emoji::EMOJI_VERSION}" title=":grinning:" class="emoji only-emoji" alt=":grinning:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"> foo<br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji only-emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20">d​:wink: <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"><br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20">d<br>
            <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"></p>
          HTML

          expect(cook(md)).to eq(html.strip)
        end

        it "does use emoji CDN when enabled" do
          SiteSetting.external_emoji_url = "https://emoji.cdn.com"

          html = <<~HTML
            <blockquote>
            <p>This is a quote with a regular emoji <img src="https://emoji.cdn.com/twitter/upside_down_face.png?v=#{Emoji::EMOJI_VERSION}" title=":upside_down_face:" class="emoji" alt=":upside_down_face:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with an emoji shortcut <img src="https://emoji.cdn.com/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with a Unicode emoji <img src="https://emoji.cdn.com/twitter/sunglasses.png?v=#{Emoji::EMOJI_VERSION}" title=":sunglasses:" class="emoji" alt=":sunglasses:" loading="lazy" width="20" height="20"></p>
            </blockquote>
          HTML

          expect(cook(md)).to eq(html.strip)
        end

        it "does use emoji CDN when others CDNs are also enabled" do
          set_cdn_url("https://cdn.com")
          setup_s3
          SiteSetting.s3_cdn_url = "https://s3.cdn.com"
          SiteSetting.external_emoji_url = "https://emoji.cdn.com"

          html = <<~HTML
            <blockquote>
            <p>This is a quote with a regular emoji <img src="https://emoji.cdn.com/twitter/upside_down_face.png?v=#{Emoji::EMOJI_VERSION}" title=":upside_down_face:" class="emoji" alt=":upside_down_face:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with an emoji shortcut <img src="https://emoji.cdn.com/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20"></p>
            </blockquote>
            <blockquote>
            <p>This is a quote with a Unicode emoji <img src="https://emoji.cdn.com/twitter/sunglasses.png?v=#{Emoji::EMOJI_VERSION}" title=":sunglasses:" class="emoji" alt=":sunglasses:" loading="lazy" width="20" height="20"></p>
            </blockquote>
          HTML

          expect(cook(md)).to eq(html.strip)
        end
      end

      it "do off topic quoting of posts from secure categories" do
        category = Fabricate(:category, read_restricted: true)
        topic = Fabricate(:topic, title: "this is topic with secret category", category: category)

        expected = <<~HTML
          <aside class="quote no-group" data-username="maja" data-post="3" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="/t/#{topic.id}/3">#{I18n.t("on_another_topic")}</a></div>
          <blockquote>
          <p>I have nothing to say.</p>
          </blockquote>
          </aside>
        HTML

        expect(
          cook(
            "[quote=\"maja, post:3, topic:#{topic.id}\"]\nI have nothing to say.\n[/quote]",
            topic_id: 1,
          ),
        ).to eq(n(expected))
      end

      it "do off topic quoting with the force_quote_link opt and no topic_id opt provided" do
        topic = Fabricate(:topic, title: "This is an off-topic topic")

        expected = <<~HTML
          <aside class="quote no-group" data-username="maja" data-post="3" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-an-off-topic-topic/#{topic.id}/3">#{topic.title}</a></div>
          <blockquote>
          <p>I have nothing to say.</p>
          </blockquote>
          </aside>
        HTML

        cooked =
          cook(
            "[quote=\"maja, post:3, topic:#{topic.id}\"]\nI have nothing to say.\n[/quote]",
            force_quote_link: true,
          )
        expect(cooked).to eq(n(expected))
      end

      it "indifferent about missing quotations" do
        md = <<~MD
          [quote=#{user.username}, post:123, topic:456, full:true]

          ddd

          [/quote]
        MD
        html = <<~HTML
          <aside class="quote no-group" data-username="#{user.username}" data-post="123" data-topic="456" data-full="true">
          <div class="title">
          <div class="quote-controls"></div>
          <img loading="lazy" alt="" width="24" height="24" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/48.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end

      it "indifferent about curlies and no curlies" do
        md = <<~MD
          [quote=“#{user.username}, post:123, topic:456, full:true”]

          ddd

          [/quote]
        MD
        html = <<~HTML
          <aside class="quote no-group" data-username="#{user.username}" data-post="123" data-topic="456" data-full="true">
          <div class="title">
          <div class="quote-controls"></div>
          <img loading="lazy" alt="" width="24" height="24" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/48.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end

      it "trims spaces on quote params" do
        md = <<~MD
          [quote="#{user.username}, post:555, topic: 666"]
          ddd
          [/quote]
        MD

        html = <<~HTML
          <aside class="quote no-group" data-username="#{user.username}" data-post="555" data-topic="666">
          <div class="title">
          <div class="quote-controls"></div>
          <img loading="lazy" alt="" width="24" height="24" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/48.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end
    end

    context "with primary user group" do
      let(:default_avatar) do
        "//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png"
      end
      fab!(:group)
      fab!(:user) { Fabricate(:user, primary_group: group) }

      before { User.stubs(:default_template).returns(default_avatar) }

      it "adds primary group class to referenced users quote" do
        topic = Fabricate(:topic, title: "this is a test topic")
        expected = <<~HTML
          <aside class="quote group-#{group.name}" data-username="#{user.username}" data-post="2" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img loading="lazy" alt="" width="24" height="24" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/48.png" class="avatar"><a href="http://test.localhost/t/this-is-a-test-topic/#{topic.id}/2">This is a test topic</a></div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(
          cook(
            "[quote=\"#{user.username}, post:2, topic:#{topic.id}\"]\nddd\n[/quote]",
            topic_id: 1,
          ),
        ).to eq(n(expected))
      end
    end

    it "can handle inline block bbcode" do
      cooked = PrettyText.cook("[quote]te **s** t[/quote]")

      html = <<~HTML
        <aside class="quote no-group">
        <blockquote>
        <p>te <strong>s</strong> t</p>
        </blockquote>
        </aside>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "handles bbcode edge cases" do
      expect(PrettyText.cook "[constructor]\ntest").to eq("<p>[constructor]<br>\ntest</p>")
    end

    it "can handle quote edge cases" do
      expect(PrettyText.cook("[quote]abc\ntest\n[/quote]")).not_to include("aside")
      expect(PrettyText.cook("[quote]  \ntest\n[/quote]  ")).to include("aside")
      expect(PrettyText.cook("a\n[quote]\ntest\n[/quote]\n\n\na")).to include("aside")
      expect(PrettyText.cook("- a\n[quote]\ntest\n[/quote]\n\n\na")).to include("aside")
      expect(PrettyText.cook("[quote]\ntest")).not_to include("aside")
      expect(PrettyText.cook("[quote]\ntest\n[/quote]z")).not_to include("aside")

      nested = <<~MD
        [quote]
        a
        [quote]
        b
        [/quote]
        c
        [/quote]
      MD

      cooked = PrettyText.cook(nested)
      expect(cooked.scan("aside").length).to eq(4)
      expect(cooked.scan("quote]").length).to eq(0)
    end

    context "with letter avatar" do
      context "with subfolder" do
        it "should have correct avatar url" do
          set_subfolder "/forum"
          md = <<~MD
            [quote="#{user.username}, post:123, topic:456, full:true"]
            ddd
            [/quote]
          MD
          expect(PrettyText.cook(md)).to include("/forum/letter_avatar_proxy")
        end
      end
    end
  end

  describe "Mentions" do
    it "can handle mentions after abbr" do
      expect(PrettyText.cook("test <abbr>test</abbr>\n\n@bob")).to eq(
        "<p>test <abbr>test</abbr></p>\n<p><span class=\"mention\">@bob</span></p>",
      )
    end

    it "should handle 3 mentions in a row" do
      expect(
        PrettyText.cook("@hello @hello @hello"),
      ).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span></p>"
    end

    it "can handle mention edge cases" do
      expect(PrettyText.cook("hi\n@s")).to eq("<p>hi<br>\n<span class=\"mention\">@s</span></p>")
      expect(PrettyText.cook("hi\n@ss")).to eq("<p>hi<br>\n<span class=\"mention\">@ss</span></p>")
      expect(PrettyText.cook("hi\n@s.")).to eq("<p>hi<br>\n<span class=\"mention\">@s</span>.</p>")
      expect(PrettyText.cook("hi\n@s.s")).to eq(
        "<p>hi<br>\n<span class=\"mention\">@s.s</span></p>",
      )
      expect(PrettyText.cook("hi\n@.s.s")).to eq("<p>hi<br>\n@.s.s</p>")
    end

    it "handles user and group mentions correctly" do
      %w[User user2].each { |username| Fabricate(:user, username: username) }

      Fabricate(:group, name: "Group", mentionable_level: Group::ALIAS_LEVELS[:everyone])
      Fabricate(
        :group,
        name: "Group2",
        mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
      )

      [
        [
          "hi @uSer! @user2 hi",
          '<p>hi <a class="mention" href="/u/user">@uSer</a>! <a class="mention" href="/u/user2">@user2</a> hi</p>',
        ],
        [
          "hi\n@user. @GROUP @somemention @group2",
          %Q|<p>hi<br>\n<a class="mention" href="/u/user">@user</a>. <a class="mention-group notify" href="/groups/group">@GROUP</a> <span class="mention">@somemention</span> <a class="mention-group" href="/groups/group2">@group2</a></p>|,
        ],
      ].each { |input, expected| expect(PrettyText.cook(input)).to eq(expected) }
    end

    context "with subfolder" do
      it "handles user and group mentions correctly" do
        set_subfolder "/forum"

        Fabricate(:user, username: "user1")
        Fabricate(:group, name: "groupA", mentionable_level: Group::ALIAS_LEVELS[:everyone])

        input = "hi there @user1 and @groupA"
        expected =
          '<p>hi there <a class="mention" href="/forum/u/user1">@user1</a> and <a class="mention-group notify" href="/forum/groups/groupa">@groupA</a></p>'

        expect(PrettyText.cook(input)).to eq(expected)
      end
    end

    it "does not assign the notify class to a group that can't be mentioned" do
      group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:members],
          mentionable_level: Group::ALIAS_LEVELS[:nobody],
        )

      expect(PrettyText.cook("test @#{group.name} test")).to eq(
        %Q|<p>test <a class="mention-group" href="/groups/#{group.name}">@#{group.name}</a> test</p>|,
      )
    end

    it "assigns the notify class if the user can mention" do
      group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:members],
          mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
        )

      expect(PrettyText.cook("test @#{group.name} test", user_id: Fabricate(:admin).id)).to eq(
        %Q|<p>test <a class="mention-group notify" href="/groups/#{group.name}">@#{group.name}</a> test</p>|,
      )
    end

    it "does not mention staged users" do
      user = Fabricate(:user, staged: true)

      expect(PrettyText.cook("something @#{user.username} something")).to eq(
        %Q|<p>something <span class="mention">@#{user.username}</span> something</p>|,
      )
    end

    context "when mentions are disabled" do
      before { SiteSetting.enable_mentions = false }

      it "should not convert mentions to links" do
        expect(PrettyText.cook("hi @user")).to eq("<p>hi @user</p>")
      end
    end

    it "can handle mentions inside a hyperlink" do
      expect(PrettyText.cook("<a> @inner</a> ")).to match_html "<p><a> @inner</a></p>"
    end

    it "can handle mentions inside a hyperlink" do
      expect(
        PrettyText.cook("[link @inner](http://site.com)"),
      ).to match_html '<p><a href="http://site.com" rel="noopener nofollow ugc">link @inner</a></p>'
    end

    it "can handle a list of mentions" do
      expect(PrettyText.cook("@a,@b")).to match_html(
        '<p><span class="mention">@a</span>,<span class="mention">@b</span></p>',
      )
    end

    it "should handle group mentions with a hyphen and without" do
      expect(
        PrettyText.cook("@hello @hello-hello"),
      ).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello-hello</span></p>"
    end

    it "should allow for @mentions to have punctuation" do
      expect(PrettyText.cook("hello @bob's @bob,@bob; @bob\"")).to match_html(
        "<p>hello <span class=\"mention\">@bob</span>'s <span class=\"mention\">@bob</span>,<span class=\"mention\">@bob</span>; <span class=\"mention\">@bob</span>\"</p>",
      )
    end

    it "should not treat a medium link as a mention" do
      expect(PrettyText.cook(". http://test/@sam")).not_to include("mention")
    end

    context "with Unicode usernames disabled" do
      before { SiteSetting.unicode_usernames = false }

      it "does not detect mention" do
        expect(PrettyText.cook("Hello @狮子")).to_not include("mention")
      end
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "does detect mention" do
        expect(
          PrettyText.cook("Hello @狮子"),
        ).to match_html '<p>Hello <span class="mention">@狮子</span></p>'
      end
    end

    context "with pretty_text_extract_mentions modifier" do
      it "allows changing the mentions extracted" do
        cooked_html = <<~HTML
        <p>
          <a class="mention" href="/u/test">@test</a>,
          <a class="mention-group" href="/g/test-group">@test-group</a>,
          <a class="custom-mention" href="/custom-mention">@test-custom</a>,
          <a class="mention" href="/u/test1">test1</a>,
          this is a test
        </p>
        HTML

        extracted_mentions = PrettyText.extract_mentions(Nokogiri::HTML5.fragment(cooked_html))
        expect(extracted_mentions).to contain_exactly("test", "test-group")

        Plugin::Instance
          .new
          .register_modifier(:pretty_text_extract_mentions) do |mentions, cooked_text|
            custom_mentions =
              cooked_text
                .css(".custom-mention")
                .map do |e|
                  if (name = e.inner_text)
                    name = name[1..-1]
                    name = User.normalize_username(name)
                    name
                  end
                end

            mentions + custom_mentions
          end

        extracted_mentions = PrettyText.extract_mentions(Nokogiri::HTML5.fragment(cooked_html))
        expect(extracted_mentions).to include("test", "test-group", "test-custom")
      ensure
        DiscoursePluginRegistry.clear_modifiers!
      end
    end
  end

  describe "code fences" do
    it "indents code correctly" do
      code = <<~MD
         X
         ```
              #
              x
         ```
      MD
      cooked = PrettyText.cook(code)

      html = <<~HTML
        <p>X</p>
        <pre><code class="lang-auto">     #
             x
        </code></pre>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "doesn't replace emoji in code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("```\n💣`\n```\n")).not_to match(/\:bomb\:/)
    end

    it "can include code class correctly" do
      SiteSetting.highlighted_languages += "|c++|structured-text|p21"

      # keep in mind spaces should be trimmed per spec
      expect(PrettyText.cook("```   ruby the mooby\n`````")).to eq(
        '<pre data-code-wrap="ruby"><code class="lang-ruby"></code></pre>',
      )
      expect(PrettyText.cook("```cpp\ncpp\n```")).to match_html(
        "<pre data-code-wrap=\"cpp\"><code class='lang-cpp'>cpp\n</code></pre>",
      )
      expect(PrettyText.cook("```\ncpp\n```")).to match_html(
        "<pre><code class='lang-auto'>cpp\n</code></pre>",
      )
      expect(PrettyText.cook("```text\ncpp\n```")).to match_html(
        "<pre><code class='lang-plaintext'>cpp\n</code></pre>",
      )
      expect(PrettyText.cook("```custom\ncustom content\n```")).to match_html(
        "<pre data-code-wrap='custom'><code class='lang-custom'>custom content\n</code></pre>",
      )
      expect(PrettyText.cook("```custom foo=bar\ncustom content\n```")).to match_html(
        "<pre data-code-foo='bar' data-code-wrap='custom'><code class='lang-custom'>custom content</code></pre>",
      )
      expect(PrettyText.cook("```INVALID a=1, foo=bar , baz=2\n```")).to match_html(
        "<pre data-code-a='1' data-code-foo='bar' data-code-baz='2' data-code-wrap='INVALID'><code class='lang-INVALID'>\n</code></pre>",
      )
      expect(PrettyText.cook("```text\n```")).to match_html(
        "<pre><code class='lang-plaintext'>\n</code></pre>",
      )
      expect(PrettyText.cook("```auto\n```")).to match_html(
        "<pre><code class='lang-auto'>\n</code></pre>",
      )
      expect(PrettyText.cook("```ruby startline=3 $%@#\n```")).to match_html(
        "<pre data-code-startline='3' data-code-wrap='ruby'><code class='lang-ruby'>\n</code></pre>",
      )
      expect(PrettyText.cook("```mermaid a_-你=17\n```")).to match_html(
        "<pre data-code-a_-='17' data-code-wrap='mermaid'><code class='lang-mermaid'>\n</code></pre>",
      )
      expect(
        PrettyText.cook("```mermaid foo=<script>alert(document.cookie)</script>\n```"),
      ).to match_html(
        "<pre data-code-foo='&lt;script&gt;alert(document.cookie)&lt;/script&gt;' data-code-wrap='mermaid'><code class='lang-mermaid'>\n</code></pre>",
      )
      # Check unicode bidi characters are stripped:
      expect(PrettyText.cook("```mermaid foo=\u202E begin admin o\u001C\n```")).to match_html(
        "<pre data-code-wrap='mermaid'><code class='lang-mermaid'>\n</code></pre>",
      )
      expect(PrettyText.cook("```c++\nc++\n```")).to match_html(
        "<pre data-code-wrap='c++'><code class='lang-c++'>c++\n</code></pre>",
      )
      expect(PrettyText.cook("```structured-text\nstructured-text\n```")).to match_html(
        "<pre data-code-wrap='structured-text'><code class='lang-structured-text'>structured-text\n</code></pre>",
      )
      expect(PrettyText.cook("```p21\np21\n```")).to match_html(
        "<pre data-code-wrap='p21'><code class='lang-p21'>p21\n</code></pre>",
      )
      expect(
        PrettyText.cook("<pre data-code='3' data-code-foo='1' data-malicous-code='2'></pre>"),
      ).to match_html("<pre data-code-foo='1'></pre>")
    end

    it "indents code correctly" do
      code = "X\n```\n\n    #\n    x\n```"
      cooked = PrettyText.cook(code)
      expect(cooked).to match_html(
        "<p>X</p>\n<pre><code class=\"lang-auto\">\n    #\n    x\n</code></pre>",
      )
    end

    it "does censor code fences" do
      begin
        %w[apple banana].each do |w|
          Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor])
        end
        expect(PrettyText.cook("# banana")).not_to include("banana")
      ensure
        Discourse.redis.flushdb
      end
    end

    it "strips out unicode bidirectional (bidi) override characters and replaces with a highlighted span" do
      code = <<~MD
         X
         ```auto
         var isAdmin = false;
         /*‮ begin admin only */⁦ if (isAdmin) ⁩ ⁦ {
         console.log("You are an admin.");
         /* end admins only ‮*/⁦ }
         ```
      MD
      cooked = PrettyText.cook(code)
      hidden_bidi_title = I18n.t("post.hidden_bidi_character")

      html = <<~HTML
        <p>X</p>
        <pre><code class="lang-auto">var isAdmin = false;
        /*<span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+202E&gt;</span> begin admin only */<span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+2066&gt;</span> if (isAdmin) <span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+2069&gt;</span> <span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+2066&gt;</span> {
        console.log("You are an admin.");
        /* end admins only <span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+202E&gt;</span>*/<span class="bidi-warning" title="#{hidden_bidi_title}">&lt;U+2066&gt;</span> }
        </code></pre>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "fuzzes all possible dangerous unicode bidirectional (bidi) override characters, making sure they are replaced" do
      bad_bidi = [
        "\u202A",
        "\u202B",
        "\u202C",
        "\u202D",
        "\u202E",
        "\u2066",
        "\u2067",
        "\u2068",
        "\u2069",
      ]
      bad_bidi.each do |bidi|
        code = <<~MD
        ```
        #{bidi}
        ```
        MD
        cooked = PrettyText.cook(code)
        formatted_bidi = format("&lt;U+%04X&gt;", bidi.ord)
        html = <<~HTML
          <pre><code class="lang-auto"><span class="bidi-warning" title="#{I18n.t("post.hidden_bidi_character")}">#{formatted_bidi}</span>
          </code></pre>
        HTML
        expect(cooked).to eq(html.strip)
      end
    end

    it "fuzzes all possible dangerous unicode bidirectional (bidi) override characters in solo code and pre nodes, making sure they are replaced" do
      bad_bidi = [
        "\u202A",
        "\u202B",
        "\u202C",
        "\u202D",
        "\u202E",
        "\u2066",
        "\u2067",
        "\u2068",
        "\u2069",
      ]
      bad_bidi.each do |bidi|
        code = <<~MD
        <code>#{bidi}</code>
        MD
        cooked = PrettyText.cook(code)
        formatted_bidi = format("&lt;U+%04X&gt;", bidi.ord)
        html = <<~HTML
          <p><code><span class="bidi-warning" title="#{I18n.t("post.hidden_bidi_character")}">#{formatted_bidi}</span></code></p>
        HTML
        expect(cooked).to eq(html.strip)
      end
      bad_bidi.each do |bidi|
        code = <<~MD
        <pre>#{bidi}</pre>
        MD
        cooked = PrettyText.cook(code)
        formatted_bidi = format("&lt;U+%04X&gt;", bidi.ord)
        html = <<~HTML
          <pre><span class="bidi-warning" title="#{I18n.t("post.hidden_bidi_character")}">#{formatted_bidi}</span></pre>
        HTML
        expect(cooked).to eq(html.strip)
      end
    end
  end

  describe "rel attributes" do
    before do
      SiteSetting.add_rel_nofollow_to_user_content = true
      SiteSetting.exclude_rel_nofollow_domains = "foo.com|bar.com"
    end

    it "should inject nofollow in all user provided links" do
      expect(PrettyText.cook('<a href="http://cnn.com">cnn</a>')).to match(/noopener nofollow ugc/)
    end

    it "should not inject nofollow in all local links" do
      expect(
        PrettyText.cook("<a href='#{Discourse.base_url}/test.html'>cnn</a>") !~ /nofollow ugc/,
      ).to eq(true)
    end

    it "should not inject nofollow in all subdomain links" do
      expect(
        PrettyText.cook(
          "<a href='#{Discourse.base_url.sub("http://", "http://bla.")}/test.html'>cnn</a>",
        ) !~ /nofollow ugc/,
      ).to eq(true)
    end

    it "should inject nofollow in all non subdomain links" do
      expect(
        PrettyText.cook(
          "<a href='#{Discourse.base_url.sub("http://", "http://bla")}/test.html'>cnn</a>",
        ),
      ).to match(/nofollow ugc/)
    end

    it "should not inject nofollow for foo.com" do
      expect(PrettyText.cook("<a href='http://foo.com/test.html'>cnn</a>") !~ /nofollow ugc/).to eq(
        true,
      )
    end

    it "should inject nofollow for afoo.com" do
      expect(PrettyText.cook("<a href='http://afoo.com/test.html'>cnn</a>")).to match(
        /nofollow ugc/,
      )
    end

    it "should not inject nofollow for bar.foo.com" do
      expect(
        PrettyText.cook("<a href='http://bar.foo.com/test.html'>cnn</a>") !~ /nofollow ugc/,
      ).to eq(true)
    end

    it "should not inject nofollow if omit_nofollow option is given" do
      expect(
        PrettyText.cook('<a href="http://cnn.com">cnn</a>', omit_nofollow: true) !~ /nofollow ugc/,
      ).to eq(true)
    end

    it "adds the noopener attribute even if omit_nofollow option is given" do
      raw_html = '<a href="https://www.mysite.com/" target="_blank">Check out my site!</a>'
      expect(PrettyText.cook(raw_html, omit_nofollow: true)).to match(/noopener/)
    end

    it "adds the noopener attribute even if omit_nofollow option is given" do
      raw_html = '<a href="https://www.mysite.com/" target="_blank">Check out my site!</a>'
      expect(PrettyText.cook(raw_html, omit_nofollow: false)).to match(/noopener nofollow ugc/)
    end
  end

  describe "Excerpt" do
    it "sanitizes attempts to inject invalid attributes" do
      spinner = "<a href=\"http://thedailywtf.com/\" data-bbcode=\"' class='fa fa-spin\">WTF</a>"
      expect(PrettyText.excerpt(spinner, 20)).to match_html spinner

      spinner =
        %q{<a href="http://thedailywtf.com/" title="' class=&quot;fa fa-spin&quot;&gt;&lt;img src='http://thedailywtf.com/Resources/Images/Primary/logo.gif"></a>}
      expect(PrettyText.excerpt(spinner, 20)).to match_html spinner
    end

    context "with images" do
      it "should dump images" do
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif'>", 100)).to eq("[image]")
      end

      context "with alt tags" do
        it "should keep alt tags" do
          expect(
            PrettyText.excerpt(
              "<img src='http://cnn.com/a.gif' alt='car' title='my big car'>",
              100,
            ),
          ).to eq("[car]")
        end

        describe "when alt tag is empty" do
          it "should not keep alt tags" do
            expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' alt>", 100)).to eq(
              "[#{I18n.t("excerpt_image")}]",
            )
          end
        end
      end

      context "with title tags" do
        it "should keep title tags" do
          expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' title='car'>", 100)).to eq(
            "[car]",
          )
        end

        describe "when title tag is empty" do
          it "should not keep title tags" do
            expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' title>", 100)).to eq(
              "[#{I18n.t("excerpt_image")}]",
            )
          end
        end
      end

      it "should convert images to markdown if the option is set" do
        expect(
          PrettyText.excerpt(
            "<img src='http://cnn.com/a.gif' title='car'>",
            100,
            markdown_images: true,
          ),
        ).to eq("![car](http://cnn.com/a.gif)")
      end

      it "replaces details / summary with the summary" do
        expect(
          PrettyText.excerpt("<details><summary>expand</summary><p>hello</p></details>", 6),
        ).to match_html "▶ expand"
      end

      it "should remove meta information" do
        expect(
          PrettyText.excerpt(wrapped_image, 100),
        ).to match_html "<a href='//localhost:3000/uploads/default/4399/33691397e78b4d75.png' class='lightbox' title='Screen Shot 2014-04-14 at 9.47.10 PM.png'>[image]</a>"
      end

      it "should strip images when option is set" do
        expect(
          PrettyText.excerpt("<img src='http://cnn.com/a.gif'>", 100, strip_images: true),
        ).to be_blank
        expect(
          PrettyText.excerpt(
            "<img src='http://cnn.com/a.gif'> Hello world!",
            100,
            strip_images: true,
          ),
        ).to eq("Hello world!")
      end

      it "should strip images, but keep emojis when option is set" do
        emoji_image =
          "<img src='/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}' title=':heart:' class='emoji' alt=':heart:' loading='lazy' width='20' height='20'>"
        html = "<img src='http://cnn.com/a.gif'> Hello world #{emoji_image}"

        expect(PrettyText.excerpt(html, 100, strip_images: true)).to eq("Hello world :heart:")
        expect(
          PrettyText.excerpt(html, 100, strip_images: true, keep_emoji_images: true),
        ).to match_html("Hello world #{emoji_image}")
      end
    end

    context "with emojis" do
      it "should remove broken emoji" do
        html = <<~HTML
          <img src=\"//localhost:3000/images/emoji/twitter/bike.png?v=#{Emoji::EMOJI_VERSION}\" title=\":bike:\" class=\"emoji\" alt=\":bike:\" loading=\"lazy\" width=\"20\" height=\"20\"> <img src=\"//localhost:3000/images/emoji/twitter/cat.png?v=#{Emoji::EMOJI_VERSION}\" title=\":cat:\" class=\"emoji\" alt=\":cat:\" loading=\"lazy\" width=\"20\" height=\"20\"> <img src=\"//localhost:3000/images/emoji/twitter/discourse.png?v=#{Emoji::EMOJI_VERSION}\" title=\":discourse:\" class=\"emoji\" alt=\":discourse:\" loading=\"lazy\" width=\"20\" height=\"20\">
        HTML
        expect(PrettyText.excerpt(html, 7)).to eq(":bike: &hellip;")
        expect(PrettyText.excerpt(html, 8)).to eq(":bike: &hellip;")
        expect(PrettyText.excerpt(html, 9)).to eq(":bike: &hellip;")
        expect(PrettyText.excerpt(html, 10)).to eq(":bike: &hellip;")
        expect(PrettyText.excerpt(html, 11)).to eq(":bike: &hellip;")
        expect(PrettyText.excerpt(html, 12)).to eq(":bike: :cat: &hellip;")
        expect(PrettyText.excerpt(html, 13)).to eq(":bike: :cat: &hellip;")
        expect(PrettyText.excerpt(html, 14)).to eq(":bike: :cat: &hellip;")
      end
    end

    it "should have an option to strip links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 100, strip_links: true)).to eq(
        "cnn",
      )
    end

    it "should preserve links" do
      expect(
        PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 100),
      ).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "should deal with special keys properly" do
      expect(PrettyText.excerpt("<pre><b></pre>", 100)).to eq("")
    end

    it "should truncate stuff properly" do
      expect(PrettyText.excerpt("hello world", 5)).to eq("hello&hellip;")
      expect(PrettyText.excerpt("<p>hello</p><p>world</p>", 6)).to eq("hello w&hellip;")
    end

    it "should insert a space between to Ps" do
      expect(PrettyText.excerpt("<p>a</p><p>b</p>", 5)).to eq("a b")
    end

    it "should strip quotes" do
      expect(PrettyText.excerpt("<aside class='quote'><p>a</p><p>b</p></aside>boom", 5)).to eq(
        "boom",
      )
    end

    it "should not count the surrounds of a link" do
      expect(
        PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 3),
      ).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "uses an ellipsis instead of html entities if provided with the option" do
      expect(
        PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2, text_entities: true),
      ).to match_html "<a href='http://cnn.com'>cn...</a>"
    end

    it "should truncate links" do
      expect(
        PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2),
      ).to match_html "<a href='http://cnn.com'>cn&hellip;</a>"
    end

    it "doesn't extract empty quotes as links" do
      expect(
        PrettyText.extract_links("<aside class='quote'>not a linked quote</aside>\n").to_a,
      ).to be_empty
    end

    it "doesn't extract links from elided parts" do
      expect(
        PrettyText.extract_links(
          "<details class='elided'><a href='http://cnn.com'>cnn</a></details>\n",
        ).to_a,
      ).to be_empty
    end

    def extract_urls(text)
      PrettyText.extract_links(text).map(&:url).to_a
    end

    it "should be able to extract links" do
      expect(extract_urls("<a href='http://cnn.com'>http://bla.com</a>")).to eq(["http://cnn.com"])
    end

    it "should extract links to topics" do
      expect(extract_urls("<aside class=\"quote\" data-topic=\"321\">aside</aside>")).to eq(
        ["/t/321"],
      )
    end

    it "does not extract links from hotlinked images" do
      html = <<~HTML
        <p>
          <a href="https://example.com">example</a>
        </p>

        <p>
          <a href="https://images.pexels.com/photos/1525041/pexels-photo-1525041.jpeg?auto=compress&amp;cs=tinysrgb&amp;w=1260&amp;h=750&amp;dpr=2" target="_blank" rel="noopener" class="onebox">
            <img src="https://images.pexels.com/photos/1525041/pexels-photo-1525041.jpeg?auto=compress&amp;cs=tinysrgb&amp;w=1260&amp;h=750&amp;dpr=2" width="690" height="459">
          </a>
        </p>

        <p>
          <div class="lightbox-wrapper">
            <a class="lightbox" href="//localhost:3000/uploads/default/original/1X/fb7ecffe57b3bc54321635c4f810c5a9396c802c.png" data-download-href="//localhost:3000/uploads/default/fb7ecffe57b3bc54321635c4f810c5a9396c802c" title="image">
              <img src="//localhost:3000/uploads/default/optimized/1X/fb7ecffe57b3bc54321635c4f810c5a9396c802c_2_545x500.png" alt="image" data-base62-sha1="zSPxs3tDdPBuq4dK3uJ1K3Sv8kI" width="545" height="500" data-dominant-color="F9F9F9" />
              <div class="meta">
                <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg>
                <span class="filename">image</span>
                <span class="informations">808×740 24.8 KB</span>
                <svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
              </div>
            </a>
          </div>
        </p>
      HTML

      expect(extract_urls(html)).to eq(["https://example.com"])
    end

    context "when lazy-videos" do
      it "should extract youtube url" do
        expect(
          extract_urls(
            "<div class=\"lazy-video-container\" data-video-id=\"yXEuEUQIP3Q\" data-video-title=\"Mister Rogers defending PBS to the US Senate\" data-provider-name=\"youtube\"></div>",
          ),
        ).to eq(["https://www.youtube.com/watch?v=yXEuEUQIP3Q"])
      end

      it "should extract vimeo url" do
        expect(
          extract_urls(
            "<div class=\"lazy-video-container\" data-video-id=\"786646692\" data-video-title=\"Dear Rich\" data-provider-name=\"vimeo\"></div>",
          ),
        ).to eq(["https://vimeo.com/786646692"])
      end

      it "should extract tiktok url" do
        expect(
          extract_urls(
            "<div class=\"lazy-video-container\" data-video-id=\"6718335390845095173\" data-video-title=\"Scramble up ur name &amp;amp; I’ll try to guess it😍❤️ #foryoupage #petsoftiktok...\" data-provider-name=\"tiktok\"></div>",
          ),
        ).to eq(["https://m.tiktok.com/v/6718335390845095173"])
      end
    end

    it "should extract links to posts" do
      expect(
        extract_urls("<aside class=\"quote\" data-topic=\"1234\" data-post=\"4567\">aside</aside>"),
      ).to eq(["/t/1234/4567"])
    end

    it "should not extract links to anchors" do
      expect(extract_urls("<a href='#tos'>TOS</a>")).to eq([])
    end

    it "should not extract links inside quotes" do
      links =
        PrettyText.extract_links(
          "
        <a href='http://body_only.com'>http://useless1.com</a>
        <aside class=\"quote\" data-topic=\"1234\">
          <a href='http://body_and_quote.com'>http://useless3.com</a>
          <a href='http://quote_only.com'>http://useless4.com</a>
        </aside>
        <a href='http://body_and_quote.com'>http://useless2.com</a>
        ",
        )

      expect(links.map { |l| [l.url, l.is_quote] }.sort).to eq(
        [
          ["http://body_only.com", false],
          ["http://body_and_quote.com", false],
          ["/t/1234", true],
        ].sort,
      )
    end

    it "should not extract links inside oneboxes" do
      onebox = <<~HTML
        <aside class="onebox twitterstatus" data-onebox-src="https://twitter.com/EDBPostgres/status/1402528437441634306">
          <header class="source">
            <a href="https://twitter.com/EDBPostgres/status/1402528437441634306" target="_blank" rel="noopener">twitter.com</a>
            <a href="https://twitter.com/EDBPostgres/status/1402528437441634306" target="_blank" rel="noopener">twitter.com</a>
          </header>
          <article class="onebox-body">
            <div class="tweet">Example URL: <a target="_blank" href="https://example.com" rel="noopener">example.com</a></div>
          </article>
        </aside>
      HTML

      expect(PrettyText.extract_links(onebox).map(&:url)).to contain_exactly(
        "https://twitter.com/EDBPostgres/status/1402528437441634306",
      )
    end

    it "should not preserve tags in code blocks" do
      expect(
        PrettyText.excerpt(
          "<pre><code class='handlebars'>&lt;h3&gt;Hours&lt;/h3&gt;</code></pre>",
          100,
        ),
      ).to eq("&lt;h3&gt;Hours&lt;/h3&gt;")
    end

    it "should handle nil" do
      expect(PrettyText.excerpt(nil, 100)).to eq("")
    end

    it "handles custom bbcode excerpt" do
      raw = <<~MD
      [excerpt]
      hello [site](https://site.com)
      [/excerpt]
      more stuff
      MD

      post = Fabricate(:post, raw: raw)
      expect(post.excerpt).to eq(
        "hello <a href=\"https://site.com\" rel=\"noopener nofollow ugc\">site</a>",
      )
    end

    it "handles div excerpt at the beginning of a post" do
      expect(PrettyText.excerpt("<div class='excerpt'>hi</div> test", 100)).to eq("hi")
    end

    it "handles span excerpt at the beginning of a post" do
      expect(PrettyText.excerpt("<span class='excerpt'>hi</span> test", 100)).to eq("hi")
    end

    it "ignores max excerpt length if a div excerpt is specified" do
      two_hundred = "123456789 " * 20 + "."
      text = two_hundred + "<div class='excerpt'>#{two_hundred}</div>" + two_hundred
      expect(PrettyText.excerpt(text, 100)).to eq(two_hundred)
    end

    it "ignores max excerpt length if a span excerpt is specified" do
      two_hundred = "123456789 " * 20 + "."
      text = two_hundred + "<span class='excerpt'>#{two_hundred}</span>" + two_hundred
      expect(PrettyText.excerpt(text, 100)).to eq(two_hundred)
    end

    it "unescapes html entities when we want text entities" do
      expect(PrettyText.excerpt("&#39;", 500, text_entities: true)).to eq("'")
    end

    it "should have an option to preserve emoji images" do
      emoji_image =
        "<img src='/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}' title=':heart:' class='emoji' alt=':heart:' loading='lazy' width='20' height='20'>"
      expect(PrettyText.excerpt(emoji_image, 100, keep_emoji_images: true)).to match_html(
        emoji_image,
      )
    end

    it "should have an option to remap emoji to code points" do
      emoji_image =
        "I <img src='/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}' title=':heart:' class='emoji' alt=':heart:' loading='lazy' width='20' height='20'> you <img src='/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}' title=':unknown:' class='emoji' alt=':unknown:' loading='lazy' width='20' height='20'> "
      expect(PrettyText.excerpt(emoji_image, 100, remap_emoji: true)).to match_html(
        "I ❤  you :unknown:",
      )
    end

    it "should have an option to preserve emoji codes" do
      emoji_code =
        "<img src='/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}' title=':heart:' class='emoji' alt=':heart:' loading='lazy' width='20' height='20'>"
      expect(PrettyText.excerpt(emoji_code, 100)).to eq(":heart:")
    end

    context "with option to preserve onebox source" do
      it "should return the right excerpt" do
        onebox =
          "<aside class=\"onebox allowlistedgeneric\">\n  <header class=\"source\">\n    <a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">meta.discourse.org</a>\n  </header>\n  <article class=\"onebox-body\">\n    <img src=\"https://cdn-enterprise.discourse.org/meta/user_avatar/meta.discourse.org/gerhard/200/70381_1.png\" width=\"\" height=\"\" class=\"thumbnail\">\n\n<h3><a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">Infrequent translation updates in stable branch</a></h3>\n\n<p>Well, there's an Italian translation for \"New Topic\" in beta, it's been there since November 2014 and it works here on meta.     Do you have any plugins installed? Try disabling them. I'm quite confident that it's either a plugin or a site...</p>\n\n  </article>\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n  <div style=\"clear: both\"></div>\n</aside>\n\n\n"
        expected =
          "<a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">meta.discourse.org</a>"

        expect(PrettyText.excerpt(onebox, 100, keep_onebox_source: true)).to eq(expected)

        expect(
          PrettyText.excerpt("#{onebox}\n  \n \n \n\n\n #{onebox}", 100, keep_onebox_source: true),
        ).to eq("#{expected}\n\n#{expected}")
      end

      it "should continue to strip quotes" do
        expect(
          PrettyText.excerpt(
            "<aside class='quote'><p>a</p><p>b</p></aside>boom",
            100,
            keep_onebox_source: true,
          ),
        ).to eq("boom")
      end
    end

    it "should strip audio/video" do
      html = <<~HTML
        <audio controls>
          <source src="https://awebsite.com/audio.mp3"><a href="https://awebsite.com/audio.mp3">https://awebsite.com/audio.mp3</a></source>
        </audio>
        <p>Listen to this!</p>
      HTML

      expect(PrettyText.excerpt(html, 100)).to eq("Listen to this!")

      html = <<~HTML
        <div class="onebox video-onebox">
          <video controlslist="nodownload" width="100%" height="100%" controls="">
            <source src="http://videosource.com/running.mp4">
            <a href="http://videosource.com/running.mp4">http://videosource.com/running.mp4</a>
          </video>
        </div>
        <p>Watch this, but do not include the video in the excerpt.</p>
      HTML

      ellipsis = "&hellip;"
      excerpt_size = 40
      excerpt = PrettyText.excerpt(html, excerpt_size)

      expect(excerpt.size).to eq(excerpt_size + ellipsis.size)
      expect(excerpt).to eq("Watch this, but do not include the video#{ellipsis}")
    end
  end

  describe "strip links" do
    it "returns blank for blank input" do
      expect(PrettyText.strip_links("")).to be_blank
    end

    it "does nothing to a string without links" do
      expect(PrettyText.strip_links("I'm the <b>batman</b>")).to eq("I'm the <b>batman</b>")
    end

    it "strips links but leaves the text content" do
      expect(
        PrettyText.strip_links(
          "I'm the linked <a href='http://en.wikipedia.org/wiki/Batman'>batman</a>",
        ),
      ).to eq("I'm the linked batman")
    end

    it "escapes the text content" do
      expect(
        PrettyText.strip_links(
          "I'm the linked <a href='http://en.wikipedia.org/wiki/Batman'>&lt;batman&gt;</a>",
        ),
      ).to eq("I'm the linked &lt;batman&gt;")
    end
  end

  describe "strip_image_wrapping" do
    def strip_image_wrapping(html)
      doc = Nokogiri::HTML5.fragment(html)
      described_class.strip_image_wrapping(doc)
      doc.to_html
    end

    it "doesn't change HTML when there's no wrapped image" do
      html = "<img src=\"wat.png\">"
      expect(strip_image_wrapping(html)).to eq(html)
    end

    it "strips the metadata" do
      expect(
        strip_image_wrapping(wrapped_image),
      ).to match_html "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"></a></div>"
    end
  end

  describe "format_for_email" do
    context "when (sub)domain" do
      before { Discourse.stubs(:base_path).returns("") }

      it "does not crash" do
        html = <<~HTML
          <a href="mailto:michael.brown@discourse.org?subject=Your%20post%20at%20http://try.discourse.org/t/discussion-happens-so-much/127/1000?u=supermathie">test</a>
        HTML

        expect(described_class.format_for_email(html, post)).to eq <<~HTML
          <a href="mailto:michael.brown@discourse.org?subject=Your%20post%20at%20http://try.discourse.org/t/discussion-happens-so-much/127/1000?u=supermathie">test</a>
        HTML
      end

      it "adds base url to relative links" do
        html = <<~HTML
          <p><a class="mention" href="/u/wiseguy">@wiseguy</a>, <a class="mention" href="/u/trollol">@trollol</a> what do you guys think?</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq <<~HTML
          <p><a class="mention" href="#{Discourse.base_url}/u/wiseguy">@wiseguy</a>, <a class="mention" href="#{Discourse.base_url}/u/trollol">@trollol</a> what do you guys think?</p>
        HTML
      end

      it "doesn't change external absolute links" do
        html = <<~HTML
          <p>Check out <a href="http://mywebsite.com/users/boss">this guy</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end

      it "doesn't change internal absolute links" do
        html = <<~HTML
          <p>Check out <a href="#{Discourse.base_url}/users/boss">this guy</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end

      it "can tolerate invalid URLs" do
        html = <<~HTML
          <p>Check out <a href="not a real url">this guy</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end

      it "doesn't change mailto" do
        html = <<~HTML
          <p>Contact me at <a href="mailto:username@me.com">this address</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end

      it "prefers data-original-href attribute to get Vimeo iframe link and escapes it" do
        html = <<~HTML
          <p>Check out this video – <iframe src='https://player.vimeo.com/video/329875646' data-original-href='https://vimeo.com/329875646/> <script>alert(1)</script>'></iframe>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to match(
          Regexp.escape("https://vimeo.com/329875646/%3E%20%3Cscript%3Ealert(1)%3C/script%3E"),
        )
      end

      it "creates a valid URL when data-original-href is missing from Vimeo link" do
        html = <<~HTML
          <iframe src="https://player.vimeo.com/video/508864124?h=fcbbcc92fa" width="640" height="360" frameborder="0" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>
        HTML

        expect(described_class.format_for_email(html, post)).to match(
          "https://vimeo.com/508864124/fcbbcc92fa",
        )
      end

      describe "#convert_vimeo_iframes" do
        it "converts <iframe> to <a>" do
          html = <<~HTML
            <p>This is a Vimeo link:</p>
            <iframe width="640" height="360" src="https://player.vimeo.com/video/1" data-original-href="https://vimeo.com/1" frameborder="0" allowfullscreen="" seamless="seamless" sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation"></iframe>
          HTML

          md = described_class.format_for_email(html, post)

          expect(md).not_to include("<iframe")
          expect(md).to match_html(<<~HTML)
            <p>This is a Vimeo link:</p>
            <p><a href="https://vimeo.com/1">https://vimeo.com/1</a></p>
          HTML
        end
      end

      describe "#strip_secure_uploads" do
        before do
          setup_s3
          SiteSetting.s3_cdn_url = "https://s3.cdn.com"
          SiteSetting.secure_uploads = true
          SiteSetting.login_required = true
        end

        it "replaces secure video content" do
          html = <<~HTML
            <video width="100%" height="100%" controls="">
              <source src="#{Discourse.base_url}/secure-uploads/original/1X/some-video.mp4">
                <a href="#{Discourse.base_url}/secure-uploads/original/1X/some-video.mp4">Video label</a>
              </source>
            </video>
          HTML

          md = described_class.format_for_email(html, post)

          expect(md).not_to include("<video")
          expect(md.to_s).to match(I18n.t("emails.secure_uploads_placeholder"))
          expect(md.to_s).not_to match(SiteSetting.Upload.s3_cdn_url)
        end

        it "replaces secure audio content" do
          html = <<~HTML
            <audio controls>
              <source src="#{Discourse.base_url}/secure-uploads/original/1X/some-audio.mp3">
                <a href="#{Discourse.base_url}/secure-uploads/original/1X/some-audio.mp3">Audio label</a>
              </source>
            </audio>
          HTML

          md = described_class.format_for_email(html, post)

          expect(md).not_to include("<audio")
          expect(md.to_s).to match(I18n.t("emails.secure_uploads_placeholder"))
          expect(md.to_s).not_to match(SiteSetting.Upload.s3_cdn_url)
        end

        it "replaces secure uploads within a link with a placeholder, keeping the url in an attribute" do
          url = "#{Discourse.base_url}\/secure-uploads/original/1X/testimage.png"
          html = <<~HTML
            <a href="#{url}"><img src="/secure-uploads/original/1X/testimage.png"></a>
          HTML

          md = described_class.format_for_email(html, post)

          expect(md).not_to include("<img")
          expect(md).to include("Redacted")
          expect(md).to include("data-stripped-secure-upload=\"#{url}\"")
        end

        it "does not create nested redactions from double processing because of the view media link" do
          url = "#{Discourse.base_url}\/secure-uploads/original/1X/testimage.png"
          html = <<~HTML
            <a href="#{url}"><img src="/secure-uploads/original/1X/testimage.png"></a>
          HTML

          md = described_class.format_for_email(html, post)

          expect(md.scan(/stripped-secure-view-upload/).length).to eq(1)
          expect(md.scan(/Redacted/).length).to eq(1)
        end

        it "replaces secure images with a placeholder, keeping the url in an attribute" do
          url = "/secure-uploads/original/1X/testimage.png"
          html = <<~HTML
            <img src="#{url}" width="20" height="20">
          HTML

          md = described_class.format_for_email(html, post)

          expect(md).not_to include("<img")
          expect(md).to include("Redacted")
          expect(md).to include("data-stripped-secure-upload=\"#{url}\"")
          expect(md).to include("data-width=\"20\"")
          expect(md).to include("data-height=\"20\"")
        end
      end
    end

    context "when subfolder" do
      before { Discourse.stubs(:base_path).returns("/forum") }

      it "adds base url to relative links" do
        html = <<~HTML
          <p><a class="mention" href="/forum/u/wiseguy">@wiseguy</a>, <a class="mention" href="/forum/u/trollol">@trollol</a> what do you guys think?</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq <<~HTML
          <p><a class="mention" href="#{Discourse.base_url}/u/wiseguy">@wiseguy</a>, <a class="mention" href="#{Discourse.base_url}/u/trollol">@trollol</a> what do you guys think?</p>
        HTML
      end

      it "doesn't change external absolute links" do
        html = <<~HTML
          <p>Check out <a href="https://mywebsite.com/users/boss">this guy</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end

      it "doesn't change internal absolute links" do
        html = <<~HTML
          <p>Check out <a href="#{Discourse.base_url}/users/boss">this guy</a>.</p>
        HTML

        expect(described_class.format_for_email(html, post)).to eq(html)
      end
    end
  end

  it "Is smart about linebreaks and IMG tags" do
    raw = <<~MD
    a <img>
    <img>

    <img>
    <img>

    <img>
    a

    <img>
    - li

    <img>
    ```
    test
    ```

    ```
    test
    ```
    MD

    html = <<~HTML
      <p>a <img><br>
      <img></p>
      <p><img><br>
      <img></p>
      <p><img></p>
      <p>a</p>
      <p><img></p>
      <ul>
      <li>li</li>
      </ul>
      <p><img></p>
      <pre><code class="lang-auto">test
      </code></pre>
      <pre><code class="lang-auto">test
      </code></pre>
    HTML

    expect(PrettyText.cook(raw)).to eq(html.strip)
  end

  describe "emoji" do
    it "replaces unicode emoji with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("💣")).to match(/\:bomb\:/)
    end

    it "does not replace left right arrow" do
      expect(PrettyText.cook("&harr;")).to eq("<p>↔</p>")
    end

    it "doesn't replace emoji in inline code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("`💣`")).not_to match(/\:bomb\:/)
    end

    it "replaces some glyphs that are not in the emoji range" do
      expect(PrettyText.cook("☹")).to match(/\:frowning\:/)
      expect(PrettyText.cook("☺")).to match(/\:smiling_face\:/)
      expect(PrettyText.cook("☻")).to match(/\:slight_smile\:/)
      expect(PrettyText.cook("♡")).to match(/\:heart\:/)
      expect(PrettyText.cook("❤")).to match(/\:heart\:/)
      expect(PrettyText.cook("❤️")).to match(/\:heart\:/) # in emoji range but ensure it works along others
    end

    it "replaces digits" do
      expect(PrettyText.cook("🔢")).to match(/\:1234\:/)
      expect(PrettyText.cook("1️⃣")).to match(/\:one\:/)
      expect(PrettyText.cook("#️⃣")).to match(/\:hash\:/)
      expect(PrettyText.cook("*️⃣")).to match(/\:asterisk\:/)
    end

    it "doesn't replace unicode emoji if emoji is disabled" do
      SiteSetting.enable_emoji = false
      expect(PrettyText.cook("💣")).not_to match(/\:bomb\:/)
    end

    it "doesn't replace emoji if emoji is disabled" do
      SiteSetting.enable_emoji = false
      expect(PrettyText.cook(":bomb:")).to eq("<p>:bomb:</p>")
    end

    it "doesn't replace shortcuts if disabled" do
      SiteSetting.enable_emoji_shortcuts = false
      expect(PrettyText.cook(":)")).to eq("<p>:)</p>")
    end

    it "does replace shortcuts if enabled" do
      expect(PrettyText.cook(":)")).to match("smile")
    end

    it "replaces skin toned emoji" do
      expect(PrettyText.cook("hello 👱🏿‍♀️")).to eq(
        "<p>hello <img src=\"/images/emoji/twitter/blonde_woman/6.png?v=#{Emoji::EMOJI_VERSION}\" title=\":blonde_woman:t6:\" class=\"emoji\" alt=\":blonde_woman:t6:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
      )
      expect(PrettyText.cook("hello 👩‍🎤")).to eq(
        "<p>hello <img src=\"/images/emoji/twitter/woman_singer.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_singer:\" class=\"emoji\" alt=\":woman_singer:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
      )
      expect(PrettyText.cook("hello 👩🏾‍🎓")).to eq(
        "<p>hello <img src=\"/images/emoji/twitter/woman_student/5.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_student:t5:\" class=\"emoji\" alt=\":woman_student:t5:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
      )
      expect(PrettyText.cook("hello 🤷‍♀️")).to eq(
        "<p>hello <img src=\"/images/emoji/twitter/woman_shrugging.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_shrugging:\" class=\"emoji\" alt=\":woman_shrugging:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
      )
    end

    it "correctly strips VARIATION SELECTOR-16 character (ufe0f) from some emojis" do
      expect(PrettyText.cook("❤️💣")).to match(/<img src[^>]+bomb[^>]+>/)
    end

    it "replaces Emoji from Unicode 14.0" do
      expect(PrettyText.cook("🫣")).to match(/\:face_with_peeking_eye\:/)
    end

    context "with subfolder" do
      it "prepends the subfolder path to the emoji url" do
        set_subfolder "/forum"

        expected = "src=\"/forum/images/emoji/twitter/grinning.png?v=#{Emoji::EMOJI_VERSION}\""

        expect(PrettyText.cook("😀")).to include(expected)
        expect(PrettyText.cook(":grinning:")).to include(expected)
      end

      it "prepends the subfolder path even if it is part of the emoji url" do
        set_subfolder "/info"

        expected =
          "src=\"/info/images/emoji/twitter/information_source.png?v=#{Emoji::EMOJI_VERSION}\""

        expect(PrettyText.cook("ℹ️")).to include(expected)
        expect(PrettyText.cook(":information_source:")).to include(expected)
      end
    end
  end

  describe "custom emoji" do
    it "replaces the custom emoji" do
      CustomEmoji.create!(name: "trout", upload: Fabricate(:upload))
      Emoji.clear_cache

      expect(PrettyText.cook("hello :trout:")).to match(/<img src[^>]+trout[^>]+>/)
    end
  end

  describe "custom emoji translation" do
    before do
      PrettyText.reset_translations

      SiteSetting.enable_emoji = true
      SiteSetting.enable_emoji_shortcuts = true

      plugin = Plugin::Instance.new
      plugin.translate_emoji "0:)", "otter"
    end

    after do
      Plugin::CustomEmoji.clear_cache
      PrettyText.reset_translations
    end

    it "sets the custom translation" do
      expect(PrettyText.cook("hello 0:)")).to match(/otter/)
    end
  end

  it "replaces skin toned emoji" do
    expect(PrettyText.cook("hello 👱🏿‍♀️")).to eq(
      "<p>hello <img src=\"/images/emoji/twitter/blonde_woman/6.png?v=#{Emoji::EMOJI_VERSION}\" title=\":blonde_woman:t6:\" class=\"emoji\" alt=\":blonde_woman:t6:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
    )
    expect(PrettyText.cook("hello 👩‍🎤")).to eq(
      "<p>hello <img src=\"/images/emoji/twitter/woman_singer.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_singer:\" class=\"emoji\" alt=\":woman_singer:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
    )
    expect(PrettyText.cook("hello 👩🏾‍🎓")).to eq(
      "<p>hello <img src=\"/images/emoji/twitter/woman_student/5.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_student:t5:\" class=\"emoji\" alt=\":woman_student:t5:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
    )
    expect(PrettyText.cook("hello 🤷‍♀️")).to eq(
      "<p>hello <img src=\"/images/emoji/twitter/woman_shrugging.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_shrugging:\" class=\"emoji\" alt=\":woman_shrugging:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>",
    )
  end

  it "should not treat a non emoji as an emoji" do
    expect(PrettyText.cook(":email,class_name:")).not_to include("emoji")
  end

  it "supports href schemes" do
    SiteSetting.allowed_href_schemes = "macappstore|steam"
    cooked = cook("[Steam URL Scheme](steam://store/452530)")
    expected =
      '<p><a href="steam://store/452530" rel="noopener nofollow ugc">Steam URL Scheme</a></p>'
    expect(cooked).to eq(n expected)
  end

  it "supports forbidden schemes" do
    SiteSetting.allowed_href_schemes = "macappstore|itunes"
    cooked = cook("[Steam URL Scheme](steam://store/452530)")
    expected = "<p><a>Steam URL Scheme</a></p>"
    expect(cooked).to eq(n expected)
  end

  it "applies scheme restrictions to img[src] attributes" do
    SiteSetting.allowed_href_schemes = "steam"
    cooked =
      cook "![Steam URL Image](steam://store/452530) ![Other scheme image](itunes://store/452530)"
    expected =
      '<p><img src="steam://store/452530" alt="Steam URL Image"> <img src="" alt="Other scheme image"></p>'
    expect(cooked).to eq(n expected)
  end

  it "applies scheme restrictions to track[src] and source[src]" do
    SiteSetting.allowed_href_schemes = "steam"
    cooked = cook <<~MD
      <video>
        <source src="steam://store/452530"><source src="itunes://store/452530"><track src="steam://store/452530"><track src="itunes://store/452530">
      </video>
    MD
    expect(cooked).to include <<~HTML
      <source src="steam://store/452530"><source src=""><track src="steam://store/452530"><track src="">
    HTML
  end

  it "applies scheme restrictions to source[srcset]" do
    SiteSetting.allowed_href_schemes = "steam"
    cooked = cook <<~MD
      <video>
        <source srcset="steam://store/452530 1x,itunes://store/123 2x"><source srcset="steam://store/452530"><source srcset="itunes://store/452530">
      </video>
    MD
    expect(cooked).to include <<~HTML
      <source srcset="steam://store/452530 1x,"><source srcset="steam://store/452530"><source srcset="">
    HTML
  end

  it "allows only tel URL scheme to start with a plus character" do
    SiteSetting.allowed_href_schemes = "tel|steam"
    cooked = cook("[Tel URL Scheme](tel://+452530579785)")
    expected = '<p><a href="tel://+452530579785" rel="noopener nofollow ugc">Tel URL Scheme</a></p>'
    expect(cooked).to eq(n expected)

    cooked2 = cook("[Steam URL Scheme](steam://+store/452530)")
    expected2 = "<p><a>Steam URL Scheme</a></p>"
    expect(cooked2).to eq(n expected2)
  end

  it "produces hashtag links" do
    user = Fabricate(:user)
    category = Fabricate(:category, name: "testing", slug: "testing")
    category2 = Fabricate(:category, name: "known", slug: "known")
    group = Fabricate(:group)
    private_category = Fabricate(:private_category, name: "secret", group: group, slug: "secret")
    tag = Fabricate(:tag, name: "known")
    Fabricate(:topic, tags: [tag])

    cooked = PrettyText.cook(" #unknown::tag #known #known::tag #testing #secret", user_id: user.id)

    expect(cooked).to have_tag("span", text: "#unknown::tag", with: { class: "hashtag-raw" })
    expect(cooked).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category2.url,
        "data-type": "category",
        "data-slug": category2.slug,
        "data-id": category2.id,
      },
    ) do
      with_tag("span", with: { class: "hashtag-icon-placeholder" })
    end
    expect(cooked).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": category.slug,
        "data-id": category.id,
      },
    ) do
      with_tag("span", with: { class: "hashtag-icon-placeholder" })
    end
    expect(cooked).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
      },
    ) do
      with_tag("span", with: { class: "hashtag-icon-placeholder" })
    end
    expect(cooked).to have_tag("span", text: "#secret", with: { class: "hashtag-raw" })

    # If the user hash access to the private category it should be cooked with the details + icon
    group.add(user)
    cooked = PrettyText.cook(" #unknown::tag #known #known::tag #testing #secret", user_id: user.id)
    expect(cooked).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: private_category.url,
        "data-type": "category",
        "data-slug": private_category.slug,
        "data-id": private_category.id,
      },
    ) do
      with_tag("span", with: { class: "hashtag-icon-placeholder" })
    end

    cooked = PrettyText.cook("[`a` #known::tag here](http://example.com)", user_id: user.id)

    html = <<~HTML
      <p><a href="http://example.com" rel="noopener nofollow ugc"><code>a</code> #known::tag here</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    cooked =
      PrettyText.cook("<a href='http://example.com'>`a` #known::tag here</a>", user_id: user.id)

    expect(cooked).to eq(html.strip)

    cooked = PrettyText.cook("<A href='/a'>test</A> #known::tag", user_id: user.id)
    expect(cooked).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
      },
    ) do
      with_tag("span", with: { class: "hashtag-icon-placeholder" })
    end

    # ensure it does not fight with the autolinker
    expect(PrettyText.cook(" http://somewhere.com/#known")).not_to include("hashtag")
    expect(PrettyText.cook(" http://somewhere.com/?#known")).not_to include("hashtag")
    expect(PrettyText.cook(" http://somewhere.com/?abc#known")).not_to include("hashtag")
  end

  it "can handle mixed lists" do
    # known bug in old md engine
    cooked = PrettyText.cook("* a\n\n1. b")
    expect(cooked).to match_html("<ul>\n<li>a</li>\n</ul>\n<ol>\n<li>b</li>\n</ol>")
  end

  it "can handle traditional vs non traditional newlines" do
    SiteSetting.traditional_markdown_linebreaks = true
    expect(PrettyText.cook("1\n2")).to match_html "<p>1 2</p>"

    SiteSetting.traditional_markdown_linebreaks = false
    expect(PrettyText.cook("1\n2")).to match_html "<p>1<br>\n2</p>"
  end

  it "can handle emoji by name" do
    expected = <<HTML
<p><img src="/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}\" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"><img src="/images/emoji/twitter/sunny.png?v=#{Emoji::EMOJI_VERSION}" title=":sunny:" class="emoji only-emoji" alt=":sunny:" loading="lazy" width="20" height="20"></p>
HTML
    expect(PrettyText.cook(":smile::sunny:")).to eq(expected.strip)
  end

  it "handles emoji boundaries correctly" do
    cooked = PrettyText.cook("a,:man:t2:,b")
    expected =
      "<p>a,<img src=\"/images/emoji/twitter/man/2.png?v=#{Emoji::EMOJI_VERSION}\" title=\":man:t2:\" class=\"emoji\" alt=\":man:t2:\" loading=\"lazy\" width=\"20\" height=\"20\">,b</p>"
    expect(cooked).to match(expected.strip)
  end

  it "can handle emoji by translation" do
    expected =
      "<p><img src=\"/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}\" title=\":wink:\" class=\"emoji only-emoji\" alt=\":wink:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>"
    expect(PrettyText.cook(";)")).to eq(expected)
  end

  it "can handle multiple emojis by translation" do
    cooked = PrettyText.cook(":) ;) :)")
    expect(cooked.split("img").length - 1).to eq(3)
  end

  it "handles emoji boundaries correctly" do
    expect(PrettyText.cook(",:)")).to include("emoji")
    expect(PrettyText.cook(":-)\n")).to include("emoji")
    expect(PrettyText.cook("a :)")).to include("emoji")
    expect(PrettyText.cook(":),")).not_to include("emoji")
    expect(PrettyText.cook("abcde ^:;-P")).to include("emoji")
  end

  describe "censoring" do
    after { Discourse.redis.flushdb }

    def expect_cooked_match(raw, expected_cooked)
      expect(PrettyText.cook(raw)).to eq(expected_cooked)
    end

    context "with basic words" do
      fab!(:watched_words) do
        %w[shucks whiz whizzer a**le badword* shuck$ café $uper].each do |word|
          Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: word)
        end
      end

      it "works correctly" do
        expect_cooked_match("aw shucks, golly gee whiz.", "<p>aw ■■■■■■, golly gee ■■■■.</p>")
      end

      it "doesn't censor words unless they have boundaries." do
        expect_cooked_match(
          "you are a whizzard! I love cheesewhiz. Whiz.",
          "<p>you are a whizzard! I love cheesewhiz. ■■■■.</p>",
        )
      end

      it "censors words even if previous partial matches exist." do
        expect_cooked_match(
          "you are a whizzer! I love cheesewhiz. Whiz.",
          "<p>you are a ■■■■■■■! I love cheesewhiz. ■■■■.</p>",
        )
      end

      it "won't break links by censoring them." do
        expect_cooked_match(
          "The link still works. [whiz](http://www.whiz.com)",
          '<p>The link still works. <a href="http://www.whiz.com" rel="noopener nofollow ugc">■■■■</a></p>',
        )
      end

      it "escapes regexp characters" do
        expect_cooked_match("I have a pen, I have an a**le", "<p>I have a pen, I have an ■■■■■</p>")
      end

      it "works for words ending in non-word characters" do
        expect_cooked_match(
          "Aw shuck$, I can't fix the problem with money",
          "<p>Aw ■■■■■■, I can't fix the problem with money</p>",
        )
      end

      it "works for words ending in accented characters" do
        expect_cooked_match("Let's go to a café today", "<p>Let's go to a ■■■■ today</p>")
      end

      it "works for words starting with non-word characters" do
        expect_cooked_match("Discourse is $uper amazing", "<p>Discourse is ■■■■■ amazing</p>")
      end

      it "handles * as wildcard" do
        expect_cooked_match("No badword or apple here plz.", "<p>No ■■■■■■■ or ■■■■■ here plz.</p>")
      end
    end

    context "with watched words as regular expressions" do
      before { SiteSetting.watched_words_regular_expressions = true }
      it "supports words as regular expressions" do
        %w[xyz* plee+ase].each do |word|
          Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: word)
        end

        expect_cooked_match(
          "Pleased to meet you, but pleeeease call me later, xyz123",
          "<p>Pleased to meet you, but ■■■■■■■■■ call me later, ■■■123</p>",
        )
      end

      it "supports custom boundaries" do
        Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "\\btown\\b")
        expect_cooked_match(
          "Meet downtown in your town at the townhouse on Main St.",
          "<p>Meet downtown in your ■■■■ at the townhouse on Main St.</p>",
        )
      end
    end
  end

  describe "watched words - replace & link" do
    after { Discourse.redis.flushdb }

    # Makes sure that mini_racer/libv8-node env doesn't regress
    it "finishes in a timely matter" do
      sql = 1500.times.map { |i| <<~SQL }.join
        INSERT INTO watched_words
        (created_at, updated_at, word, action, replacement)
        VALUES
        (
          :now,
          :now,
          'word_#{i}',
          :action,
          'replacement_#{i}'
        );
      SQL

      DB.exec(sql, now: Time.current, action: WatchedWord.actions[:replace])

      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "nope",
        replacement: "yep",
      )

      # Due to a bug in node 18.16 and lower this takes about 11s.
      # On node 18.19 and newer it takes about 250ms
      expect do
        Timeout.timeout(3) do
          expect(PrettyText.cook("abc nope def")).to match_html("<p>abc yep def</p>")
        end
      end.not_to raise_error
    end

    it "replaces words with other words" do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "dolor sit*",
        replacement: "something else",
      )

      expect(PrettyText.cook("Lorem ipsum dolor sit amet")).to match_html(<<~HTML)
        <p>Lorem ipsum something else amet</p>
      HTML

      expect(PrettyText.cook("Lorem ipsum dolor sits amet")).to match_html(<<~HTML)
        <p>Lorem ipsum something else amet</p>
      HTML

      expect(PrettyText.cook("Lorem ipsum dolor sittt amet")).to match_html(<<~HTML)
        <p>Lorem ipsum something else amet</p>
      HTML

      expect(PrettyText.cook("Lorem ipsum xdolor sit amet")).to match_html(<<~HTML)
        <p>Lorem ipsum xdolor sit amet</p>
      HTML
    end

    it "replaces words with wildcards" do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "*dolor*",
        replacement: "something else",
      )

      expect(PrettyText.cook("Lorem ipsum xdolorx sit amet")).to match_html(<<~HTML)
        <p>Lorem ipsum something else sit amet</p>
      HTML
    end

    it "replaces words with links" do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:link],
        word: "meta",
        replacement: "https://meta.discourse.org",
      )

      expect(PrettyText.cook("Meta is a Discourse forum")).to match_html(<<~HTML)
        <p>
          <a href=\"https://meta.discourse.org\" rel=\"noopener nofollow ugc\">Meta</a>
          is a Discourse forum
        </p>
      HTML
    end

    it "works with regex" do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "f.o",
        replacement: "test",
      )

      expect(PrettyText.cook("foo")).to match_html("<p>foo</p>")
      expect(PrettyText.cook("f.o")).to match_html("<p>test</p>")

      SiteSetting.watched_words_regular_expressions = true

      expect(PrettyText.cook("foo")).to match_html("<p>test</p>")
      expect(PrettyText.cook("f.o")).to match_html("<p>test</p>")
    end

    it "does not replace hashtags and mentions" do
      Fabricate(:user, username: "test")
      category = Fabricate(:category, slug: "test", name: "test")
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "test",
        replacement: "discourse",
      )

      cooked = PrettyText.cook("@test #test test")
      expect(cooked).to have_tag("a", text: "@test", with: { class: "mention", href: "/u/test" })
      expect(cooked).to have_tag(
        "a",
        text: "test",
        with: {
          class: "hashtag-cooked",
          href: "/c/test/#{category.id}",
          "data-type": "category",
          "data-slug": category.slug,
          "data-id": category.id,
        },
      ) do
        with_tag("span", with: { class: "hashtag-icon-placeholder" })
      end
      expect(cooked).to include("discourse")
    end

    it "does not replace hashtags and mentions when watched words are regular expressions" do
      SiteSetting.watched_words_regular_expressions = true

      Fabricate(:user, username: "test")
      category = Fabricate(:category, slug: "test", name: "test")
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:replace],
        word: "es",
        replacement: "discourse",
      )

      cooked = PrettyText.cook("@test #test test")
      expect(cooked).to have_tag("a", text: "@test", with: { class: "mention", href: "/u/test" })
      expect(cooked).to have_tag(
        "a",
        text: "test",
        with: {
          class: "hashtag-cooked",
          href: "/c/test/#{category.id}",
          "data-type": "category",
          "data-slug": category.slug,
          "data-id": category.id,
        },
      ) do
        with_tag("span", with: { class: "hashtag-icon-placeholder" })
      end
      expect(cooked).to include("tdiscourset")
    end

    it "supports overlapping words" do
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:link],
        word: "meta",
        replacement: "https://meta.discourse.org",
      )
      Fabricate(:watched_word, action: WatchedWord.actions[:replace], word: "iz", replacement: "is")
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:link],
        word: "discourse",
        replacement: "https://discourse.org",
      )

      expect(PrettyText.cook("Meta iz a Discourse forum")).to match_html(<<~HTML)
        <p>
          <a href="https://meta.discourse.org" rel="noopener nofollow ugc">Meta</a>
          is a
          <a href="https://discourse.org" rel="noopener nofollow ugc">Discourse</a>
          forum
        </p>
      HTML
    end
  end

  it "supports typographer" do
    SiteSetting.enable_markdown_typographer = true
    expect(PrettyText.cook("->")).to eq("<p> → </p>")

    SiteSetting.enable_markdown_typographer = false
    expect(PrettyText.cook("->")).to eq("<p>-&gt;</p>")
  end

  it "uses quotation marks from site settings" do
    SiteSetting.enable_markdown_typographer = true
    expect(PrettyText.cook(%q|"Do you know," he said, "what 'Discourse' is?"|)).to eq(
      "<p>“Do you know,” he said, “what ‘Discourse’ is?”</p>",
    )

    SiteSetting.markdown_typographer_quotation_marks = "„|“|‚|‘"
    expect(PrettyText.cook(%q|"Weißt du", sagte er, "was 'Discourse' ist?"|)).to eq(
      "<p>„Weißt du“, sagte er, „was ‚Discourse‘ ist?“</p>",
    )
  end

  it "handles onebox correctly" do
    expect(PrettyText.cook("http://a.com\nhttp://b.com").split("onebox").length).to eq(3)
    expect(PrettyText.cook("http://a.com\n\nhttp://b.com").split("onebox").length).to eq(3)
    expect(PrettyText.cook("a\nhttp://a.com")).to include("onebox")
    expect(PrettyText.cook("> http://a.com")).not_to include("onebox")
    expect(PrettyText.cook("a\nhttp://a.com a")).not_to include("onebox")
    expect(PrettyText.cook("a\nhttp://a.com\na")).to include("onebox")
    expect(PrettyText.cook("http://a.com")).to include("onebox")
    expect(PrettyText.cook("http://a.com ")).to include("onebox")
    expect(PrettyText.cook("http://a.com a")).not_to include("onebox")
    expect(PrettyText.cook("- http://a.com")).not_to include("onebox")
    expect(PrettyText.cook("<http://a.com>")).not_to include("onebox")
    expect(PrettyText.cook(" http://a.com")).not_to include("onebox")
    expect(PrettyText.cook("a\n http://a.com")).not_to include("onebox")
    expect(PrettyText.cook("sam@sam.com")).not_to include("onebox")
    expect(PrettyText.cook("<img src='a'>\nhttp://a.com")).to include("onebox")
  end

  it "can handle bbcode" do
    expect(PrettyText.cook("a[b]b[/b]c")).to eq('<p>a<span class="bbcode-b">b</span>c</p>')
    expect(PrettyText.cook("a[i]b[/i]c")).to eq('<p>a<span class="bbcode-i">b</span>c</p>')
  end

  it "supports empty inline BBCode" do
    expect(PrettyText.cook("a[b][/b]c")).to eq('<p>a<span class="bbcode-b"></span>c</p>')
  end

  it "can handle bbcode after a newline" do
    # this is not 100% ideal cause we get an extra p here, but this is pretty rare
    expect(PrettyText.cook("a\n[code]code[/code]")).to eq(
      "<p>a</p>\n<pre><code class=\"lang-auto\">code</code></pre>",
    )

    # this is fine
    expect(PrettyText.cook("a\na[code]code[/code]")).to eq("<p>a<br>\na<code>code</code></p>")
  end

  it "can onebox local topics" do
    op = post
    reply = Fabricate(:post, topic_id: op.topic_id)

    url = Discourse.base_url + reply.url
    quote = create_post(topic_id: op.topic.id, raw: "This is a sample reply with a quote\n\n#{url}")
    quote.reload

    expect(quote.cooked).not_to include("[quote")
  end

  it "supports tables" do
    markdown = <<~MD
      | Tables        | Are           | Cool  |
      | ------------- |:-------------:| -----:|
      | col 3 is      | right-aligned | $1600 |
    MD

    expected = <<~HTML
      <div class="md-table">
      <table>
      <thead>
      <tr>
      <th>Tables</th>
      <th style="text-align:center">Are</th>
      <th style="text-align:right">Cool</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td>col 3 is</td>
      <td style="text-align:center">right-aligned</td>
      <td style="text-align:right">$1600</td>
      </tr>
      </tbody>
      </table>
      </div>
    HTML

    expect(PrettyText.cook(markdown)).to eq(expected.strip)
  end

  it "supports img bbcode" do
    cooked = PrettyText.cook "[img]http://www.image/test.png[/img]"
    html = "<p><img src=\"http://www.image/test.png\" alt=\"\" role=\"presentation\"></p>"
    expect(cooked).to eq(html)
  end

  it "supports img bbcode entities in attributes" do
    actual = PrettyText.cook "[img]http://aaa.com/?a=1&b=<script>alert(1);</script>[/img]"
    expected =
      '<p><img src="http://aaa.com/?a=1&b=&lt;script&gt;alert(1);&lt;/script&gt;" alt="" role="presentation"></p>'
    expect(expected).to be_same_dom(actual)
  end

  it "supports email bbcode" do
    cooked = PrettyText.cook "[email]sam@sam.com[/email]"
    html = '<p><a href="mailto:sam@sam.com" data-bbcode="true">sam@sam.com</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports url bbcode" do
    cooked = PrettyText.cook "[url]http://sam.com[/url]"
    html =
      '<p><a href="http://sam.com" data-bbcode="true" rel="noopener nofollow ugc">http://sam.com</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports nesting tags in url" do
    cooked = PrettyText.cook("[url=http://sam.com][b]I am sam[/b][/url]")
    html =
      '<p><a href="http://sam.com" data-bbcode="true" rel="noopener nofollow ugc"><span class="bbcode-b">I am sam</span></a></p>'
    expect(cooked).to eq(html)
  end

  it "supports query params in bbcode url" do
    cooked =
      PrettyText.cook(
        "[url=https://www.amazon.com/Camcorder-Hausbell-302S-Control-Infrared/dp/B01KLOA1PI/?tag=discourse]BBcode link[/url]",
      )
    html =
      '<p><a href="https://www.amazon.com/Camcorder-Hausbell-302S-Control-Infrared/dp/B01KLOA1PI/?tag=discourse" data-bbcode="true" rel="noopener nofollow ugc">BBcode link</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports inline code bbcode" do
    cooked = PrettyText.cook "Testing [code]codified **stuff** and `more` stuff[/code]"
    html = "<p>Testing <code>codified **stuff** and `more` stuff</code></p>"
    expect(cooked).to eq(html)
  end

  it "supports block code bbcode" do
    cooked = PrettyText.cook "[code]\ncodified\n\n\n  **stuff** and `more` stuff\n[/code]"
    html = "<pre><code class=\"lang-auto\">codified\n\n\n  **stuff** and `more` stuff</code></pre>"
    expect(cooked).to eq(html)
  end

  it "support special handling for space in urls" do
    cooked = PrettyText.cook "http://testing.com?a%20b"
    html =
      '<p><a href="http://testing.com?a%20b" class="onebox" target="_blank" rel="noopener nofollow ugc">http://testing.com?a%20b</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports onebox for decoded urls" do
    cooked = PrettyText.cook "http://testing.com?a%50b"
    html =
      '<p><a href="http://testing.com?a%50b" class="onebox" target="_blank" rel="noopener nofollow ugc">http://testing.com?aPb</a></p>'
    expect(cooked).to eq(html)
  end

  it "should sanitize the html" do
    expect(PrettyText.cook("<test>alert(42)</test>")).to eq "<p>alert(42)</p>"
  end

  it "should not onebox magically linked urls" do
    expect(PrettyText.cook("[url]site.com[/url]")).not_to include("onebox")
  end

  it "should sanitize the html" do
    expect(PrettyText.cook("<p class='hi'>hi</p>")).to eq "<p>hi</p>"
  end

  it "should strip SCRIPT" do
    expect(PrettyText.cook("<script>alert(42)</script>")).to eq ""
    expect(PrettyText.cook("<div><script>alert(42)</script></div>")).to eq "<div></div>"
  end

  it "strips script regardless of sanitize" do
    expect(
      PrettyText.cook("<div><script>alert(42)</script></div>", sanitize: false),
    ).to eq "<div></div>"
  end

  it "should allow sanitize bypass" do
    expect(
      PrettyText.cook("<test>alert(42)</test>", sanitize: false),
    ).to eq "<p><test>alert(42)</test></p>"
  end

  # custom rule used to specify image dimensions via alt tags
  describe "image dimensions" do
    it "allows title plus dimensions" do
      cooked = PrettyText.cook <<~MD
        ![title with | title|220x100](http://png.com/my.png)
        ![](http://png.com/my.png)
        ![|220x100](http://png.com/my.png)
        ![stuff](http://png.com/my.png)
        ![|220x100,50%](http://png.com/my.png "some title")
      MD

      html = <<~HTML
        <p><img src="http://png.com/my.png" alt="title with | title" width="220" height="100"><br>
        <img src="http://png.com/my.png" alt="" role="presentation"><br>
        <img src="http://png.com/my.png" alt="" width="220" height="100" role="presentation"><br>
        <img src="http://png.com/my.png" alt="stuff"><br>
        <img src="http://png.com/my.png" alt="" title="some title" width="110" height="50" role="presentation"></p>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "ignores whitespace and allows scaling by percent, width, height" do
      cooked = PrettyText.cook <<~MD
        ![|220x100, 50%](http://png.com/my.png)
        ![|220x100 , 50%](http://png.com/my.png)
        ![|220x100 ,50%](http://png.com/my.png)
        ![|220x100,150x](http://png.com/my.png)
        ![|220x100, x50](http://png.com/my.png)
      MD

      html = <<~HTML
        <p><img src="http://png.com/my.png" alt="" width="110" height="50" role="presentation"><br>
        <img src="http://png.com/my.png" alt="" width="110" height="50" role="presentation"><br>
        <img src="http://png.com/my.png" alt="" width="110" height="50" role="presentation"><br>
        <img src="http://png.com/my.png" alt="" width="150" height="68" role="presentation"><br>
        <img src="http://png.com/my.png" alt="" width="110" height="50" role="presentation"></p>
      HTML

      expect(cooked).to eq(html.strip)
    end
  end

  describe "upload decoding" do
    it "can decode upload:// for default setup" do
      set_cdn_url("https://cdn.com")

      upload = Fabricate(:upload)

      raw = <<~RAW
      ![upload](#{upload.short_url})

      ![upload](#{upload.short_url} "some title to test")

      - ![upload](#{upload.short_url})

      - test
          - ![upload](#{upload.short_url})

      ![upload](#{upload.short_url.gsub(".png", "")})

      Inline img <img src="#{upload.short_url}">

      <div>
        Block img <img src="#{upload.short_url}">
      </div>

      [some attachment](#{upload.short_url})

      [some attachment|attachment](#{upload.short_url})

      [some attachment|random](#{upload.short_url})
      RAW

      cdn_url = Discourse.store.cdn_url(upload.url)

      cooked = <<~HTML
        <p><img src="#{cdn_url}" alt="upload" data-base62-sha1="#{upload.base62_sha1}"></p>
        <p><img src="#{cdn_url}" alt="upload" title="some title to test" data-base62-sha1="#{upload.base62_sha1}"></p>
        <ul>
        <li>
        <p><img src="#{cdn_url}" alt="upload" data-base62-sha1="#{upload.base62_sha1}"></p>
        </li>
        <li>
        <p>test</p>
        <ul>
        <li><img src="#{cdn_url}" alt="upload" data-base62-sha1="#{upload.base62_sha1}"></li>
        </ul>
        </li>
        </ul>
        <p><img src="#{cdn_url}" alt="upload" data-base62-sha1="#{upload.base62_sha1}"></p>
        <p>Inline img <img src="#{cdn_url}" data-base62-sha1="#{upload.base62_sha1}"></p>
        <div>
          Block img <img src="#{cdn_url}" data-base62-sha1="#{upload.base62_sha1}">
        </div>
        <p><a href="#{upload.short_path}">some attachment</a></p>
        <p><a class="attachment" href="#{upload.short_path}">some attachment</a></p>
        <p><a href="#{upload.short_path}">some attachment|random</a></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(cooked.strip)
    end

    it "can place a blank image if we can not find the upload" do
      raw = <<~MD
      ![upload](upload://abcABC.png)

      [some attachment|attachment](upload://abcdefg.png)
      MD

      cooked = <<~HTML
      <p><img src="/images/transparent.png" alt="upload" data-orig-src="upload://abcABC.png"></p>
      <p><a class="attachment" href="/404" data-orig-href="upload://abcdefg.png">some attachment</a></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(cooked.strip)
    end
  end

  it "can properly allowlist iframes" do
    SiteSetting.allowed_iframes = "https://bob.com/a|http://silly.com/?EMBED="
    raw = <<~HTML
      <iframe src='https://www.google.com/maps/Embed?testing'></iframe>
      <iframe src='https://bob.com/a?testing'></iframe>
      <iframe src='HTTP://SILLY.COM/?EMBED=111'></iframe>
    HTML

    # we require explicit HTTPS here
    html = <<~HTML
      <iframe src="https://bob.com/a?testing"></iframe>
      <iframe src="HTTP://SILLY.COM/?EMBED=111"></iframe>
    HTML

    cooked = PrettyText.cook(raw).strip

    expect(cooked).to eq(html.strip)
  end

  it "can skip relative paths in allowlist iframes" do
    SiteSetting.allowed_iframes = "https://bob.com/abc/def"
    raw = <<~HTML
      <iframe src='https://bob.com/abc/def'></iframe>
      <iframe src='https://bob.com/abc/def/../ghi'></iframe>
      <iframe src='https://bob.com/abc/def/ghi/../../jkl'></iframe>
    HTML

    html = <<~HTML
      <iframe src="https://bob.com/abc/def"></iframe>
    HTML

    expect(PrettyText.cook(raw).strip).to eq(html.strip)
  end

  it "You can disable linkify" do
    md = "www.cnn.com test.it http://test.com https://test.ab https://a"
    cooked = PrettyText.cook(md)

    html = <<~HTML
      <p><a href="http://www.cnn.com" rel="noopener nofollow ugc">www.cnn.com</a> test.it <a href="http://test.com" rel="noopener nofollow ugc">http://test.com</a> <a href="https://test.ab" rel="noopener nofollow ugc">https://test.ab</a> <a href="https://a" rel="noopener nofollow ugc">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # notice how cnn.com is no longer linked but it is
    SiteSetting.markdown_linkify_tlds = "not_com|it"

    cooked = PrettyText.cook(md)
    html = <<~HTML
    <p>www.cnn.com <a href="http://test.it" rel="noopener nofollow ugc">test.it</a> <a href="http://test.com" rel="noopener nofollow ugc">http://test.com</a> <a href="https://test.ab" rel="noopener nofollow ugc">https://test.ab</a> <a href="https://a" rel="noopener nofollow ugc">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # no tlds anymore
    SiteSetting.markdown_linkify_tlds = ""

    cooked = PrettyText.cook(md)
    html = <<~HTML
      <p>www.cnn.com test.it <a href="http://test.com" rel="noopener nofollow ugc">http://test.com</a> <a href="https://test.ab" rel="noopener nofollow ugc">https://test.ab</a> <a href="https://a" rel="noopener nofollow ugc">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # lastly ... what about no linkify
    SiteSetting.enable_markdown_linkify = false

    cooked = PrettyText.cook(md)

    html = <<~HTML
      <p>www.cnn.com test.it http://test.com https://test.ab https://a</p>
    HTML
  end

  it "has a proper data whitelist on div" do
    cooked = PrettyText.cook("<div data-theme-a='a'>test</div>")
    expect(cooked).to include("data-theme-a")
  end

  it "allowlists lang attribute" do
    cooked =
      PrettyText.cook(
        "<p lang='fr'>tester</p><div lang='fr'>tester</div><span lang='fr'>tester</span>",
      )
    expect(cooked).to eq(
      "<p lang=\"fr\">tester</p><div lang=\"fr\">tester</div><span lang=\"fr\">tester</span>",
    )
  end

  it "allowlists ruby tags" do
    # read all about ruby chars at: https://en.wikipedia.org/wiki/Ruby_character
    # basically it is super hard to remember every single rare letter when there are
    # so many, so ruby tags provide a hint.
    #
    html = (<<~MD).strip
      <ruby lang="je">
        <rb lang="je">X</rb>
        漢 <rp>(</rp><rt lang="je"> ㄏㄢˋ </rt><rp>)</rp>
      </ruby>
    MD

    cooked = PrettyText.cook html

    expect(cooked).to eq(html)
  end

  describe "d-wrap" do
    it "wraps the [wrap] tag inline" do
      cooked = PrettyText.cook("[wrap=toc]taco[/wrap]")

      html = <<~HTML
        <div class="d-wrap" data-wrap="toc">
        <p>taco</p>
        </div>
      HTML

      expect(cooked).to eq(html.strip)

      cooked = PrettyText.cook("Hello [wrap=toc id=1]taco[/wrap] world")

      html = <<~HTML
        <p>Hello <span class="d-wrap" data-id="1" data-wrap="toc">taco</span> world</p>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "wraps the [wrap] tag in block" do
      # can interfere with parsing
      SiteSetting.enable_markdown_typographer = true

      md = <<~MD
        [wrap=toc id=“a” aa='b"' bb="f'"]
        taco1
        [/wrap]
      MD

      cooked = PrettyText.cook(md)

      html = <<~HTML
        <div class="d-wrap" data-aa="b&amp;quot;" data-bb="f'" data-id="a" data-wrap="toc">
        <p>taco1</p>
        </div>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "wraps the [wrap] tag without content" do
      md = <<~MD
        [wrap=toc]
        [/wrap]
      MD

      cooked = PrettyText.cook(md)

      html = <<~HTML
        <div class="d-wrap" data-wrap="toc"></div>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "adds attributes as data-attributes" do
      cooked = PrettyText.cook("[wrap=toc name=\"single quote's\" id='1\"2']taco[/wrap]")

      html = <<~HTML
        <div class="d-wrap" data-id="1&amp;quot;2" data-name="single quote's" data-wrap="toc">
        <p>taco</p>
        </div>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "prevents xss" do
      cooked = PrettyText.cook('[wrap=toc foo="<script>console.log(1)</script>"]taco[/wrap]')

      html = <<~HTML
        <div class="d-wrap" data-foo="&amp;lt;script&amp;gt;console.log(1)&amp;lt;/script&amp;gt;" data-wrap="toc">
        <p>taco</p>
        </div>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "allows a limited set of attributes chars" do
      cooked = PrettyText.cook('[wrap=toc fo@"èk-"!io=bar]taco[/wrap]')

      html = <<~HTML
        <p>[wrap=toc fo@"èk-"!io=bar]taco[/wrap]</p>
      HTML

      expect(cooked).to eq(html.strip)
    end
  end

  it "adds anchor links to headings" do
    cooked = PrettyText.cook("# Hello world")

    html = <<~HTML
      <h1>
      <a name="hello-world-1" class="anchor" href="#hello-world-1"></a>
      Hello world
      </h1>
    HTML

    expect(cooked).to match_html(html)
  end

  describe "customizing markdown-it rules" do
    it "customizes the markdown-it rules correctly" do
      cooked = PrettyText.cook("This is some text **bold**", markdown_it_rules: [])

      expect(cooked).to eq("<p>This is some text **bold**</p>")

      cooked = PrettyText.cook("This is some text **bold**", markdown_it_rules: ["emphasis"])

      expect(cooked).to eq("<p>This is some text <strong>bold</strong></p>")
    end
  end

  describe "enabling/disabling features" do
    it "allows features to be overridden" do
      cooked = PrettyText.cook(":grin: @mention", features_override: [])

      expect(cooked).to eq("<p>:grin: @mention</p>")

      cooked = PrettyText.cook(":grin: @mention", features_override: ["emoji"])

      expect(cooked).to eq(
        "<p><img src=\"/images/emoji/twitter/grin.png?v=#{Emoji::EMOJI_VERSION}\" title=\":grin:\" class=\"emoji\" alt=\":grin:\" loading=\"lazy\" width=\"20\" height=\"20\"> @mention</p>",
      )

      cooked = PrettyText.cook(":grin: @mention", features_override: %w[mentions text-post-process])

      expect(cooked).to eq("<p>:grin: <span class=\"mention\">@mention</span></p>")
    end
  end

  it "does not amend HTML when scrubbing" do
    md = <<~MD
      <s>\n\nhello\n\n</s>
    MD

    html = <<~HTML
      <s>\n<p>hello</p>\n</s>
    HTML

    cooked = PrettyText.cook(md)

    expect(cooked.strip).to eq(html.strip)
  end

  it "handles deprecations correctly" do
    Rails
      .logger
      .expects(:warn)
      .once
      .with("[PrettyText] Deprecation notice: Some deprecation message")

    PrettyText.v8.eval <<~JS
      require("discourse-common/lib/deprecated").default("Some deprecation message");
    JS
  end

  describe "video thumbnails" do
    before do
      SiteSetting.authorized_extensions = "mp4|png"
      @video_upload = Fabricate(:upload, original_filename: "video.mp4", extension: "mp4")
    end

    after { Upload.where(original_filename: ["404.png", "#{@video_upload.sha1}.png"]).destroy_all }

    it "does not link to a thumbnail image if the video source is missing" do
      Fabricate(:upload, original_filename: "404.png", extension: "png")

      html = <<~HTML
          <p></p><div class="video-placeholder-container" data-video-src="/404"></div><p></p>
        HTML
      doc = Nokogiri::HTML5.fragment(html)
      described_class.add_video_placeholder_image(doc)

      expect(doc.to_html).to eq(html)
    end

    it "links to a thumbnail image if the video source is valid" do
      thumbnail =
        Fabricate(:upload, original_filename: "#{@video_upload.sha1}.png", extension: "png")

      html = <<~HTML
        <p></p><div class="video-placeholder-container" data-video-src="#{@video_upload.url}"></div><p></p>
      HTML
      doc = Nokogiri::HTML5.fragment(html)
      described_class.add_video_placeholder_image(doc)

      html_with_thumbnail = <<~HTML
        <p></p><div class="video-placeholder-container" data-video-src="#{@video_upload.url}" data-thumbnail-src="http://test.localhost#{thumbnail.url}"></div><p></p>
      HTML

      expect(doc.to_html).to eq(html_with_thumbnail)
    end
  end
end
