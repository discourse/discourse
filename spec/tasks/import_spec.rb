# frozen_string_literal: true

RSpec.describe "import:ensure_consistency" do
  before { silence_warnings { Discourse::Application.load_tasks } }

  describe "insert_user_actions for mentions" do
    fab!(:author, :user)
    fab!(:mentioned_user, :user)
    fab!(:topic)

    def add_mentions(post, *mentioned_users)
      anchors =
        mentioned_users.map do |user|
          %|<a class="mention" href="/u/#{user.username_lower}">@#{user.username}</a>|
        end
      post.update_columns(cooked: "<p>hello #{anchors.join(" ")}</p>")
    end

    def mention_actions
      UserAction.where(action_type: UserAction::MENTION)
    end

    it "creates one action per mentioned user, attributed to the post author" do
      other_user = Fabricate(:user)
      post = Fabricate(:post, topic: topic, user: author)
      add_mentions(post, mentioned_user, other_user)

      capture_stdout { insert_user_actions }

      expect(
        mention_actions.pluck(:user_id, :acting_user_id, :target_topic_id, :target_post_id),
      ).to contain_exactly(
        [mentioned_user.id, author.id, topic.id, post.id],
        [other_user.id, author.id, topic.id, post.id],
      )
      expect(mention_actions.first.created_at).to eq_time(post.created_at)

      expect { capture_stdout { insert_user_actions } }.not_to change { mention_actions.count }
    end

    it "skips ineligible posts and mentions" do
      pm_post = Fabricate(:post, topic: Fabricate(:private_message_topic), user: author)
      add_mentions(pm_post, mentioned_user)

      restricted_category = Fabricate(:private_category, group: Fabricate(:group))
      restricted_post =
        Fabricate(:post, topic: Fabricate(:topic, category: restricted_category), user: author)
      add_mentions(restricted_post, mentioned_user)

      deleted_post = Fabricate(:post, topic: topic, user: author)
      add_mentions(deleted_post, mentioned_user)
      deleted_post.update_columns(deleted_at: Time.zone.now)

      post_in_deleted_topic = Fabricate(:post, user: author)
      add_mentions(post_in_deleted_topic, mentioned_user)
      post_in_deleted_topic.topic.update_columns(deleted_at: Time.zone.now)

      post_in_invisible_topic = Fabricate(:post, user: author)
      add_mentions(post_in_invisible_topic, mentioned_user)
      post_in_invisible_topic.topic.update_columns(visible: false)

      self_mention_post = Fabricate(:post, topic: topic, user: author)
      add_mentions(self_mention_post, author)

      group_mention_post = Fabricate(:post, topic: topic, user: author)
      group_mention_post.update_columns(
        cooked: '<p><a class="mention-group" href="/groups/staff">@staff</a></p>',
      )

      unknown_user_post = Fabricate(:post, topic: topic, user: author)
      unknown_user_post.update_columns(
        cooked: '<p><a class="mention" href="/u/no_such_user">@no_such_user</a></p>',
      )

      capture_stdout { insert_user_actions }

      expect(mention_actions).to be_empty
    end

    it "makes the first mention badge grantable via backfill" do
      post = Fabricate(:post, topic: topic, user: author)
      add_mentions(post, mentioned_user)

      capture_stdout { insert_user_actions }
      BadgeGranter.backfill(Badge.find(Badge::FirstMention))

      user_badges = UserBadge.where(badge_id: Badge::FirstMention)
      expect(user_badges.pluck(:user_id, :post_id)).to contain_exactly([author.id, post.id])
      expect(user_badges.first.granted_at).to eq_time(post.created_at)
    end

    it "ignores mentions inside quotes and oneboxes" do
      post = Fabricate(:post, topic: topic, user: author)
      post.update_columns(cooked: <<~HTML)
    <aside class="quote" data-post="1" data-topic="#{topic.id}">
      <blockquote><a class="mention" href="/u/#{mentioned_user.username_lower}">@x</a></blockquote>
    </aside>
    <aside class="onebox">
      <a class="mention" href="/u/#{mentioned_user.username_lower}">@x</a>
    </aside>
  HTML

      capture_stdout { insert_user_actions }
      expect(mention_actions).to be_empty
    end
  end

  describe "insert_quoted_posts" do
    fab!(:author, :user)
    fab!(:quoted_author, :user)
    fab!(:topic)

    fab!(:quoted_post) { Fabricate(:post, user: quoted_author) }

    def add_quote(post, target, attribute_order: :post_first)
      attributes =
        if attribute_order == :post_first
          %|data-post="#{target.post_number}" data-topic="#{target.topic_id}"|
        else
          %|data-username="#{target.user.username}" data-topic="#{target.topic_id}" data-post="#{target.post_number}"|
        end
      post.update_columns(
        cooked:
          "<aside class=\"quote no-group\" #{attributes}><blockquote>quoted</blockquote></aside>",
      )
    end

    it "rebuilds quoted_posts, sets reply_quoted and creates quote user actions" do
      parent = Fabricate(:post, topic: topic, user: quoted_author)
      reply = Fabricate(:post, topic: topic, user: author, reply_to_post_number: parent.post_number)
      add_quote(reply, parent)

      other_post = Fabricate(:post, topic: topic, user: author)
      add_quote(other_post, quoted_post, attribute_order: :username_first)

      capture_stdout do
        insert_quoted_posts
        insert_user_actions
      end

      expect(QuotedPost.pluck(:post_id, :quoted_post_id)).to contain_exactly(
        [reply.id, parent.id],
        [other_post.id, quoted_post.id],
      )
      expect(reply.reload.reply_quoted).to eq(true)
      expect(other_post.reload.reply_quoted).to eq(false)

      quote_actions = UserAction.where(action_type: UserAction::QUOTE)
      expect(
        quote_actions.pluck(:user_id, :acting_user_id, :target_topic_id, :target_post_id),
      ).to contain_exactly(
        [quoted_author.id, author.id, topic.id, reply.id],
        [quoted_author.id, author.id, other_post.topic_id, other_post.id],
      )

      expect { capture_stdout { insert_quoted_posts } }.not_to change { QuotedPost.count }
    end

    it "skips self-quotes and unresolvable quote targets" do
      self_quoting_post = Fabricate(:post, topic: topic, user: author)
      add_quote(self_quoting_post, self_quoting_post)

      post_with_missing_target = Fabricate(:post, topic: topic, user: author)
      post_with_missing_target.update_columns(
        cooked: '<aside class="quote" data-post="999" data-topic="999999"></aside>',
      )

      capture_stdout do
        insert_quoted_posts
        insert_user_actions
      end

      expect(QuotedPost.count).to eq(0)
      expect(UserAction.where(action_type: UserAction::QUOTE)).to be_empty
    end

    it "makes the first quote badge grantable via backfill" do
      quoting_post = Fabricate(:post, topic: topic, user: author)
      add_quote(quoting_post, quoted_post)

      capture_stdout { insert_quoted_posts }
      BadgeGranter.backfill(Badge.find(Badge::FirstQuote))

      expect(UserBadge.where(badge_id: Badge::FirstQuote).pluck(:user_id)).to contain_exactly(
        author.id,
      )
    end
  end

  describe "insert_topic_links" do
    fab!(:author, :user)
    fab!(:target_author, :user)
    fab!(:topic)

    fab!(:target_post) { Fabricate(:post, user: target_author) }

    def linked_post_actions
      UserAction.where(action_type: UserAction::LINKED)
    end

    it "rebuilds internal topic links with reflections and creates linked user actions" do
      post = Fabricate(:post, topic: topic, user: author)
      post.update_columns(
        cooked:
          "<p><a href=\"#{Discourse.base_url}/t/#{target_post.topic_id}/#{target_post.post_number}\">link</a></p>",
      )

      capture_stdout do
        insert_topic_links
        insert_user_actions
      end

      expect(
        TopicLink.pluck(:topic_id, :post_id, :link_topic_id, :link_post_id, :reflection),
      ).to contain_exactly(
        [topic.id, post.id, target_post.topic_id, target_post.id, false],
        [target_post.topic_id, target_post.id, topic.id, post.id, true],
      )
      expect(TopicLink.pluck(:internal).uniq).to eq([true])

      expect(
        linked_post_actions.pluck(:user_id, :acting_user_id, :target_topic_id, :target_post_id),
      ).to contain_exactly([target_author.id, author.id, topic.id, post.id])

      expect { capture_stdout { insert_topic_links } }.not_to change { TopicLink.count }
    end

    it "skips external links, same-topic links and links inside quotes" do
      same_topic_target = Fabricate(:post, topic: topic, user: target_author)
      post = Fabricate(:post, topic: topic, user: author)
      post.update_columns(cooked: <<~HTML)
          <p><a href="https://example.com/t/#{target_post.topic_id}">external</a></p>
          <p><a href="#{Discourse.base_url}/t/#{topic.id}/#{same_topic_target.post_number}">same topic</a></p>
          <aside class="quote" data-post="1" data-topic="#{topic.id}">
            <a href="#{Discourse.base_url}/t/#{target_post.topic_id}">quoted link</a>
          </aside>
        HTML

      capture_stdout do
        insert_topic_links
        insert_user_actions
      end

      expect(TopicLink.count).to eq(0)
      expect(linked_post_actions).to be_empty
    end

    it "makes the first link badge grantable via backfill" do
      post = Fabricate(:post, topic: topic, user: author)
      post.update_columns(
        cooked: "<p><a href=\"#{Discourse.base_url}/t/#{target_post.topic_id}\">link</a></p>",
      )

      capture_stdout { insert_topic_links }
      BadgeGranter.backfill(Badge.find(Badge::FirstLink))

      expect(UserBadge.where(badge_id: Badge::FirstLink).pluck(:user_id)).to contain_exactly(
        author.id,
      )
    end
  end
end
