# frozen_string_literal: true

RSpec.describe Import::ParticipationBadges do
  let(:service) { described_class.new }

  after do
    # Unconditionally clean up the notification-suppression hook so it can never
    # leak into later examples/spec files (leaked modifiers raise in the test
    # environment).
    stub, block = service.instance_variable_get(:@badge_notification_suppression)
    if stub && block
      DiscoursePluginRegistry.unregister_modifier(
        stub,
        :badge_granter_suppress_notification,
        &block
      )
    end
  end

  # Marks a fabricated post as belonging to the import by writing the same
  # import_id custom field the bulk importer leaves on every imported post, so
  # the scoped derivations (which only rebuild imported posts) pick it up.
  def mark_imported(post)
    PostCustomField.create!(
      post_id: post.id,
      name: Import::ParticipationBadges::IMPORT_ID_FIELD,
      value: "1",
    )
    post
  end

  describe "#derive_quotes" do
    fab!(:topic)
    fab!(:poster, :user)

    it "creates quoted_posts from a quote post's reply-parent linkage gated on quote bbcode" do
      parent = Fabricate(:post, topic: topic, post_number: 1, user: poster, raw: "the source post")
      quoter =
        Fabricate(
          :post,
          topic: topic,
          post_number: 2,
          user: poster,
          raw: 'hi [quote="X"]..[/quote]',
        )
      # Mirror a real rebake: a [quote] renders as a quote aside in cooked.
      quoter.update!(
        cooked:
          '<aside class="quote no-group" data-username="X"><blockquote><p>..</p></blockquote></aside>',
      )
      quoter.update!(reply_to_post_number: parent.post_number)
      mark_imported(quoter)

      service.derive_quotes

      expect(QuotedPost.where(post_id: quoter.id, quoted_post_id: parent.id).count).to eq(1)
    end

    it "skips quote posts with no reply parent (e.g. root/self posts)" do
      root =
        Fabricate(
          :post,
          topic: topic,
          post_number: 1,
          user: poster,
          raw: 'hi [quote="X"]..[/quote]',
        )
      root.update!(
        cooked:
          '<aside class="quote no-group" data-username="X"><blockquote><p>..</p></blockquote></aside>',
      )
      mark_imported(root)

      service.derive_quotes

      expect(QuotedPost.where(post_id: root.id).count).to eq(0)
    end

    it "does not count a post whose cooked has no quote aside (escaped [quote in code)" do
      parent = Fabricate(:post, topic: topic, post_number: 1, user: poster, raw: "the source post")
      code =
        Fabricate(
          :post,
          topic: topic,
          post_number: 2,
          user: poster,
          raw: 'pasted "[quote="X"]" as literal text in a code block, not a live quote',
        )
      # After rebake the pasted [quote=...] stays escaped text, so cooked has no
      # quote aside even though the reply parent resolves. It must not be treated
      # as a quote.
      code.update!(cooked: "<p>pasted &quot;[quote=&#34;X&#34;]&quot; as literal text</p>")
      code.update!(reply_to_post_number: parent.post_number)
      mark_imported(code)

      service.derive_quotes

      expect(QuotedPost.where(post_id: code.id).count).to eq(0)
    end

    it "resolves a quote aside's explicit data-topic/data-post target over the reply parent" do
      target = Fabricate(:post, topic: topic, post_number: 1, user: poster, raw: "the target")
      # The reply parent differs from the explicit quote target.
      parent = Fabricate(:post, topic: topic, post_number: 2, user: poster, raw: "reply parent")
      quoter =
        Fabricate(
          :post,
          topic: topic,
          post_number: 3,
          user: poster,
          raw: 'hi [quote="X", post:#{target.post_number}, topic:#{topic.id}]..[/quote]',
        )
      quoter.update!(
        cooked:
          %{<aside class="quote no-group" data-username="X" data-post="#{target.post_number}" data-topic="#{topic.id}"><blockquote><p>..</p></blockquote></aside>},
      )
      quoter.update!(reply_to_post_number: parent.post_number)
      mark_imported(quoter)

      service.derive_quotes

      expect(QuotedPost.where(post_id: quoter.id, quoted_post_id: parent.id).count).to eq(0)
      expect(QuotedPost.where(post_id: quoter.id, quoted_post_id: target.id).count).to eq(1)
    end

    it "resolves a targeted quote even when the quote post has no reply parent" do
      target = Fabricate(:post, topic: topic, post_number: 1, user: poster, raw: "the target")
      quoter =
        Fabricate(
          :post,
          topic: topic,
          post_number: 2,
          user: poster,
          raw: 'hi [quote="X", post:#{target.post_number}, topic:#{topic.id}]..[/quote]',
        )
      quoter.update!(
        cooked:
          %{<aside class="quote no-group" data-username="X" data-post="#{target.post_number}" data-topic="#{topic.id}"><blockquote><p>..</p></blockquote></aside>},
      )
      mark_imported(quoter)

      service.derive_quotes

      expect(QuotedPost.where(post_id: quoter.id, quoted_post_id: target.id).count).to eq(1)
    end

    it "leaves non-imported posts' quote rows untouched (scope to this import)" do
      parent = Fabricate(:post, topic: topic, user: poster, raw: "the source post")
      existing = Fabricate(:post, topic: topic, user: poster, raw: "hello base site")
      existing.update!(
        cooked: '<aside class="quote no-group"><blockquote><p>..</p></blockquote></aside>',
      )
      # A pre-existing base-site quote row that must survive a delta import.
      QuotedPost.create!(post_id: existing.id, quoted_post_id: parent.id)

      service.derive_quotes

      expect(QuotedPost.where(post_id: existing.id, quoted_post_id: parent.id).count).to eq(1)
    end

    it "re-derives quote rows in source-chronological order so MIN(id) picks the earliest quote" do
      shared_target = Fabricate(:post, topic: topic, user: poster, raw: "target")
      older = Fabricate(:post, topic: topic, user: poster, raw: "older quote")
      older.update!(
        cooked:
          '<aside class="quote no-group" data-username="X"><blockquote><p>a</p></blockquote></aside>',
        reply_to_post_number: shared_target.post_number,
        created_at: 10.days.ago,
      )
      mark_imported(older)
      newer = Fabricate(:post, topic: topic, user: poster, raw: "newer quote")
      newer.update!(
        cooked:
          '<aside class="quote no-group" data-username="X"><blockquote><p>b</p></blockquote></aside>',
        reply_to_post_number: shared_target.post_number,
      )
      mark_imported(newer)

      service.derive_quotes

      older_row = QuotedPost.find_by(post_id: older.id)
      newer_row = QuotedPost.find_by(post_id: newer.id)
      expect(older_row).to be_present
      expect(newer_row).to be_present
      # The older post's quote row is inserted first, so FirstQuote's MIN(id)
      # resolves to it rather than the chronologically-later quote.
      expect(older_row.id).to be < newer_row.id
    end

    it "flags reply_quoted when the reply parent is among the rebuilt quote targets" do
      parent = Fabricate(:post, topic: topic, post_number: 1, user: poster, raw: "the reply parent")
      quoter =
        Fabricate(
          :post,
          topic: topic,
          post_number: 2,
          user: poster,
          raw: 'hi [quote="X"]..[/quote]',
        )
      quoter.update!(
        cooked:
          '<aside class="quote no-group" data-username="X"><blockquote><p>..</p></blockquote></aside>',
      )
      quoter.update!(reply_to_post_number: parent.post_number, reply_quoted: false)
      mark_imported(quoter)

      service.derive_quotes

      # Mirrors the reply_quoted consistency QuotedPost.extract_from applies, so
      # quote-as-reply tips (suppress_reply_when_quoting) hide redundant context.
      expect(quoter.reload.reply_quoted).to eq(true)
    end

    it "leaves reply_quoted false when the quote does not target the reply parent" do
      target = Fabricate(:post, topic: topic, user: poster, raw: "a different target")
      parent = Fabricate(:post, topic: topic, post_number: 2, user: poster, raw: "reply parent")
      quoter =
        Fabricate(
          :post,
          topic: topic,
          post_number: 3,
          user: poster,
          raw: 'hi [quote="X"]..[/quote]',
        )
      # The aside targets `target` via data-topic/data-post, not the reply parent.
      quoter.update!(
        cooked:
          %{<aside class="quote no-group" data-username="X" data-post="#{target.post_number}" data-topic="#{topic.id}"><blockquote><p>..</p></blockquote></aside>},
      )
      quoter.update!(reply_to_post_number: parent.post_number, reply_quoted: true)
      mark_imported(quoter)

      service.derive_quotes

      expect(quoter.reload.reply_quoted).to eq(false)
    end
  end

  describe "#derive_mentions" do
    fab!(:topic)
    fab!(:author, :user)
    fab!(:mentioned, :user)
    fab!(:other, :user)

    def post_with_mentions(mention_users)
      post = Fabricate(:post, topic: topic, user: author, raw: "hello")
      mentions =
        mention_users.map { |u| %{<a class="mention" href="/u/#{u.username}">@#{u.username}</a>} }
      post.update!(cooked: "<p>#{mentions.join(" ")}</p>")
      mark_imported(post)
      post
    end

    it "logs MENTION user_actions from resolved mention anchors in cooked" do
      post = post_with_mentions([mentioned, other])

      service.derive_mentions

      [mentioned, other].each do |u|
        expect(
          UserAction.where(
            action_type: UserAction::MENTION,
            user_id: u.id,
            target_post_id: post.id,
            acting_user_id: author.id,
          ).count,
        ).to eq(1)
      end
    end

    it "only logs mentions from imported posts (leaves base-site posts untouched)" do
      imported = post_with_mentions([mentioned])
      native_post = Fabricate(:post, topic: topic, user: author, raw: "hello")
      native_post.update!(
        cooked: %{<p><a class="mention" href="/u/#{other.username}">@#{other.username}</a></p>},
      )
      # `native_post` has no import_id custom field → represents pre-existing
      # base-site content whose (live) mention actions must not be recreated on
      # delta/existing-site imports.

      service.derive_mentions

      expect(
        UserAction.where(
          action_type: UserAction::MENTION,
          target_post_id: imported.id,
          user_id: mentioned.id,
        ).count,
      ).to eq(1)
      expect(
        UserAction.where(action_type: UserAction::MENTION, target_post_id: native_post.id).count,
      ).to eq(0)
    end

    it "removes stale MENTION actions whose current anchor disappeared (delta run)" do
      # Simulate a delta re-import: the post previously mentioned `other`, then
      # the source post's mention was removed. Rebaking does not run PostAlerter,
      # so derive_mentions must drop the stale action before re-logging current
      # anchors, or a revoked First Mention would linger.
      post = post_with_mentions([])
      UserAction.log_action!(
        action_type: UserAction::MENTION,
        user_id: other.id,
        target_topic_id: topic.id,
        target_post_id: post.id,
        acting_user_id: author.id,
        created_at: post.created_at,
      )

      service.derive_mentions

      expect(
        UserAction.where(action_type: UserAction::MENTION, target_post_id: post.id).count,
      ).to eq(0)
    end

    it "replaces a mention that flipped to a self-mention (stale row dropped)" do
      post = post_with_mentions([other])
      UserAction.log_action!(
        action_type: UserAction::MENTION,
        user_id: other.id,
        target_topic_id: topic.id,
        target_post_id: post.id,
        acting_user_id: author.id,
        created_at: post.created_at,
      )
      # Now the post only mentions its own author (self-mention → must be skipped
      # and the prior mention of `other` dropped).
      post.update!(
        cooked: %{<p><a class="mention" href="/u/#{author.username}">@#{author.username}</a></p>},
      )

      service.derive_mentions

      expect(
        UserAction.where(action_type: UserAction::MENTION, target_post_id: post.id).count,
      ).to eq(0)
    end

    it "skips self-mentions and non-/u/ mention hrefs" do
      post = Fabricate(:post, topic: topic, user: author, raw: "hello")
      post.update!(
        cooked:
          %{<a class="mention" href="/u/#{author.username}">@#{author.username}</a> <a class="mention-group" href="/g/admins">@admins</a>},
      )
      mark_imported(post)

      service.derive_mentions

      expect(
        UserAction.where(action_type: UserAction::MENTION, target_post_id: post.id).count,
      ).to eq(0)
    end

    it "skips a mention that resolves to an ambiguous (duplicate) username" do
      u1 = Fabricate(:user)
      post = Fabricate(:post, topic: topic, user: author, raw: "hello")
      post.update!(cooked: %{<a class="mention" href="/u/#{u1.username}">@#{u1.username}</a>})
      mark_imported(post)

      # DB uniqueness makes a real duplicate username impossible; stub the seam
      # to simulate a lookup resolving to more than one account.
      allow(User).to receive(:where).and_call_original
      allow(User).to receive(:where).with(username_lower: u1.username_lower).and_return(
        double(pluck: [u1.id, u1.id + 1]),
      )

      service.derive_mentions

      expect(
        UserAction.where(action_type: UserAction::MENTION, target_post_id: post.id).count,
      ).to eq(0)
    end

    it "strips the base path and decodes percent-encoded usernames in mention hrefs" do
      begin
        SiteSetting.unicode_usernames = true
      rescue Discourse::InvalidParameters
        # already enabled / not tunable in this install; proceed with the default
      end
      user = Fabricate(:user, username: "名ab")
      allow(Discourse).to receive(:base_path).and_return("/forum")
      post = Fabricate(:post, topic: topic, user: author, raw: "hello")
      post.update!(
        cooked:
          %{<a class="mention" href="/forum/u/#{UrlHelper.encode_component(user.username)}">@名</a>},
      )
      mark_imported(post)

      service.derive_mentions

      expect(
        UserAction.where(
          action_type: UserAction::MENTION,
          user_id: user.id,
          target_post_id: post.id,
          acting_user_id: author.id,
        ).count,
      ).to eq(1)
    end
  end

  describe "#derive_links" do
    fab!(:topic)
    fab!(:poster, :user)
    fab!(:author, :user)

    it "runs TopicLink.extract_from only for posts whose cooked contains an anchor" do
      with_link = Fabricate(:post, topic: topic, user: poster, raw: "see this")
      with_link.update!(cooked: '<p><a href="https://example.com/x">x</a></p>')
      mark_imported(with_link)
      no_link = Fabricate(:post, topic: topic, user: author, raw: "no links here")
      mark_imported(no_link)

      visited = []
      allow(TopicLink).to receive(:extract_from) { |post| visited << post.id }

      service.derive_links

      expect(visited).to include(with_link.id)
      expect(visited).not_to include(no_link.id)
    end

    it "suppresses the external title-crawl during the pass and restores it" do
      with_link = Fabricate(:post, topic: topic, user: poster, raw: "see this")
      with_link.update!(cooked: '<p><a href="https://example.com/x">x</a></p>')
      mark_imported(with_link)

      suppressed_during = nil
      allow(TopicLink).to receive(:extract_from) do
        suppressed_during = TopicLink.crawl_link_title(1).nil?
      end
      allow(Jobs).to receive(:enqueue)

      service.derive_links

      # Crawl is a no-op while the pass runs…
      expect(suppressed_during).to eq(true)
      # …and is restored afterwards (enqueues the crawl job again).
      TopicLink.crawl_link_title(1)
      expect(Jobs).to have_received(:enqueue).with(:crawl_topic_link, topic_link_id: 1)
    end

    it "preserves reflections other posts placed on a re-derived post (no blanket delete)" do
      # A chronologically-later post that qualifies for re-derivation carries a
      # reflection created by an earlier post (post_id = this post, link_post_id
      # = the linking post). Re-deriving it must not wipe that reflection the way
      # a blanket `TopicLink.where(post_id:).delete_all` would.
      other_topic = Fabricate(:topic)
      target = Fabricate(:post, topic: topic, user: poster, raw: "target")
      target.update!(cooked: '<p><a href="https://example.com/x">x</a></p>')
      mark_imported(target)
      other = Fabricate(:post, topic: other_topic, user: poster, raw: "other")

      reflection =
        TopicLink.create!(
          post_id: target.id,
          user_id: poster.id,
          topic_id: topic.id,
          url: "https://example.com/reflected",
          domain: "example.com",
          reflection: true,
          link_topic_id: other_topic.id,
          link_post_id: other.id,
        )

      # Isolate the deletion behaviour; the per-post cleanup must not remove it.
      allow(TopicLink).to receive(:extract_from)

      service.derive_links

      expect(TopicLink.find_by(id: reflection.id)).to be_present
    end

    it "recreates forward links in source order so FirstLink MIN(id) picks the earliest link" do
      other_topic = Fabricate(:topic, user: poster)
      target_a = Fabricate(:post, topic: other_topic, user: poster, raw: "a target")
      target_b = Fabricate(:post, topic: other_topic, user: poster, raw: "b target")
      base = Discourse.base_url

      url_a = "#{base}/t/#{other_topic.slug}/#{other_topic.id}/#{target_a.post_number}"
      url_b = "#{base}/t/#{other_topic.slug}/#{other_topic.id}/#{target_b.post_number}"

      earlier = Fabricate(:post, topic: topic, user: poster, raw: "earlier")
      earlier.update!(cooked: %{<p>see <a href="#{url_a}">a</a></p>})
      earlier.update!(created_at: 10.days.ago)
      mark_imported(earlier)
      later = Fabricate(:post, topic: topic, user: poster, raw: "later")
      later.update!(cooked: %{<p>see <a href="#{url_b}">b</a></p>})
      mark_imported(later)

      # Simulate the earlier (id-shuffled) rebake: the *later* post's forward row
      # was created first and so has the lower id. Without reconstruction,
      # extract_from's ON CONFLICT DO NOTHING would keep these ids, so FirstLink's
      # MIN(id) would still pick the later post.
      later_link =
        TopicLink.create!(
          post_id: later.id,
          user_id: poster.id,
          topic_id: topic.id,
          url: url_b,
          domain: URI.parse(base).host,
          internal: true,
          link_topic_id: other_topic.id,
          link_post_id: target_b.id,
        )
      earlier_link =
        TopicLink.create!(
          post_id: earlier.id,
          user_id: poster.id,
          topic_id: topic.id,
          url: url_a,
          domain: URI.parse(base).host,
          internal: true,
          link_topic_id: other_topic.id,
          link_post_id: target_a.id,
        )
      expect(earlier_link.id).to be > later_link.id

      service.derive_links

      earlier_row = TopicLink.find_by(post_id: earlier.id)
      later_row = TopicLink.find_by(post_id: later.id)
      expect(earlier_row).to be_present
      expect(later_row).to be_present
      # Reconstruction restored source order so MIN(topic_links.id) = earlier's row.
      expect(earlier_row.id).to be < later_row.id
    end

    it "preserves non-badge topic links and their click records during reconstruction" do
      # External and same-topic (or quote) links are not FirstLink candidates, so
      # reconstruction must leave them — and the Docker title/crawl data and any
      # click records attached to them — intact instead of deleting them.
      with_link = Fabricate(:post, topic: topic, user: poster, raw: "see this")
      with_link.update!(cooked: %{<p><a href="https://example.com/x">x</a></p>})
      mark_imported(with_link)

      external =
        TopicLink.create!(
          post_id: with_link.id,
          user_id: poster.id,
          topic_id: topic.id,
          url: "https://example.com/x",
          domain: "example.com",
          title: "A crawled title",
        )
      # A click record whose topic_link would be orphaned by a blanket delete_all.
      click = Fabricate(:topic_link_click, topic_link: external)

      allow(TopicLink).to receive(:extract_from)

      service.derive_links

      expect(TopicLink.find_by(id: external.id)).to be_present
      expect(external.reload.title).to eq("A crawled title")
      expect(TopicLinkClick.find_by(id: click.id)).to be_present
    end

    it "does not re-timestamp reflection rows to their (imported) target post's created_at" do
      other_topic = Fabricate(:topic, user: poster)
      # A reflection stored on this imported post but owned by a non-imported
      # source post in another topic.
      target = Fabricate(:post, topic: topic, user: poster, raw: "target")
      target.update!(created_at: 10.days.ago)
      mark_imported(target)
      source = Fabricate(:post, topic: other_topic, user: poster, raw: "source")
      source.update!(created_at: 1.day.ago)

      reflection =
        TopicLink.create!(
          post_id: target.id,
          user_id: poster.id,
          topic_id: topic.id,
          url: "https://example.com/r",
          domain: "example.com",
          reflection: true,
          link_topic_id: other_topic.id,
          link_post_id: source.id,
          created_at: source.created_at,
        )

      allow(TopicLink).to receive(:extract_from)

      service.derive_links

      reflection.reload
      # post_id is the (imported) target; only a forward-only rebase guard keeps
      # the reflection's timestamp (its source post's) intact instead of stamping
      # it with the target's 10-days-ago created_at.
      expect(reflection.created_at).to be_within(1.second).of(source.created_at)
    end

    it "aborts instead of proceeding when link extraction fails" do
      with_link = Fabricate(:post, topic: topic, user: poster, raw: "see this")
      with_link.update!(cooked: %{<p><a href="https://example.com/x">x</a></p>})
      mark_imported(with_link)

      allow(TopicLink).to receive(:extract_from).and_raise("boom")

      # Forward candidates were already torn down; a silent rescue would hand the
      # auto-revoking badge backfill incomplete link data, so the failure must
      # surface and stop the pass.
      expect { service.derive_links }.to raise_error(RuntimeError, /aborting before badge backfill/)
    end
  end

  describe "#backfill_participation_badges" do
    it "backfills each participation badge via Jobs::BackfillBadge" do
      badge1 = Fabricate(:badge, name: "Backfill Alpha")
      badge2 = Fabricate(:badge, name: "Backfill Beta")
      allow(Badge).to receive(:where).with(
        id: Import::ParticipationBadges::PARTICIPATION_BADGE_IDS,
      ).and_return(Badge.where(id: [badge1.id, badge2.id]))

      job = instance_double(Jobs::BackfillBadge)
      allow(Jobs::BackfillBadge).to receive(:new).and_return(job)
      allow(job).to receive(:execute)

      service.backfill_participation_badges

      expect(job).to have_received(:execute).with(badge_id: badge1.id)
      expect(job).to have_received(:execute).with(badge_id: badge2.id)
      # Notification suppression was active for the pass.
      expect(service.instance_variable_get(:@badge_notification_suppression)).to be_present
    end
  end

  describe "#grant_all" do
    it "runs every derivation then the backfill" do
      service = described_class.new
      allow(service).to receive(:derive_quotes)
      allow(service).to receive(:derive_mentions)
      allow(service).to receive(:derive_links)
      allow(service).to receive(:backfill_participation_badges)

      service.grant_all

      expect(service).to have_received(:derive_quotes).ordered
      expect(service).to have_received(:derive_mentions).ordered
      expect(service).to have_received(:derive_links).ordered
      expect(service).to have_received(:backfill_participation_badges).ordered
    end

    it "aborts before the badge backfill when link extraction raises" do
      service = described_class.new
      allow(service).to receive(:derive_quotes)
      allow(service).to receive(:derive_mentions)
      allow(service).to receive(:derive_links).and_raise("link extraction broke")
      allow(service).to receive(:backfill_participation_badges)

      expect { service.grant_all }.to raise_error("link extraction broke")

      # The auto-revoking backfill must never run on incomplete link data.
      expect(service).not_to have_received(:backfill_participation_badges)
    end
  end
end
