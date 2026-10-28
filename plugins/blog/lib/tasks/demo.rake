# frozen_string_literal: true

module Blog
  module DemoUsers
    def self.admin
      User.real.where(admin: true).order(:id).first || abort("Create an admin user first")
    end

    def self.members(limit)
      User
        .real
        .activated
        .not_suspended
        .not_silenced
        .not_staged
        .where(admin: false)
        .order("RANDOM()")
        .limit(limit)
        .to_a
    end
  end
end

namespace :blog do
  desc "Set up an editorial demo on the local development site"
  task demo: :environment do
    abort "Demo content is only available in development" unless Rails.env.development?
    admin = Blog::DemoUsers.admin
    blog = Category.find_by(id: SiteSetting.blog_category) || Category.find_by(slug: "blog")
    unless blog
      blog = Category.new(name: "Blog", slug: "blog", user: admin)
      blog.set_permissions(everyone: :create_post, staff: :full)
      blog.save!
    end
    drafts =
      Category.find_by(id: SiteSetting.blog_drafts_category) ||
        Category.find_by(slug: "blog-drafts")
    unless drafts
      drafts = Category.new(name: "Blog editorial", slug: "blog-drafts", user: admin)
      drafts.set_permissions(staff: :full)
      drafts.save!
    end
    SiteSetting.blog_url = SiteSetting.blog_url.presence || "https://blog.localhost"
    blog_uri = URI(SiteSetting.blog_url)
    SiteSetting.blog_category = blog.id
    SiteSetting.blog_drafts_category = drafts.id
    SiteSetting.blog_title = "Fieldnotes"
    SiteSetting.blog_description =
      "Ideas in progress, things we’ve learned, and conversations worth having."
    SiteSetting.blog_about = <<~MD
      A little space for longer thoughts, built right into our community.

      **Fieldnotes** is a working demonstration of Discourse Blog. Every article starts as a topic, and every conversation stays connected to the story that started it.

      ## A place to think out loud

      We believe the interesting part often happens after you press publish. Ask a question, share an experience, or offer a different perspective in the discussion beneath each article.

      These sample articles are demo content. Replace them with your own when you are ready.
    MD
    SiteSetting.blog_enabled = true
    Blog::Configuration.ensure_ready!
    SiteSetting.embed_full_app = true
    SiteSetting.embed_full_app_signin_flow = true
    embed_host =
      blog_uri.port == blog_uri.default_port ? blog_uri.host : "#{blog_uri.host}:#{blog_uri.port}"
    EmbeddableHost.find_or_create_by!(host: embed_host) { |host| host.category_id = blog.id }

    examples = [
      {
        path: "/a-small-home-for-big-ideas",
        title: "A small home for big ideas",
        excerpt:
          "A blog should feel like a quiet place to read, with an open door to the conversation. This is our first step toward that.",
        featured: true,
        raw: <<~MD,
          *This is a demo article. Make yourself at home and try the conversation below.*

          There is something satisfying about a page that gets out of your way. A title, a little context, and room for an idea to develop.

          That is the starting point for this blog: **a calm reading experience, connected to a living community.** No separate publishing system. No comments database drifting away from the article. Just one place to write, and two good ways to experience it.

          ## Write where the conversation happens

          Every article begins as a Discourse topic. Before it is ready, it lives in a private drafts category. You can revise it, add images, ask fellow editors for feedback, and preview the finished page.

          Publishing is an explicit decision. It gives the story a permanent address and opens the discussion to everyone.

          > The article is the beginning of the conversation, not the end of it.

          ## Small by default

          The words arrive as ordinary HTML. You do not need to load an application to read them. When you reach the discussion, Discourse joins you there: real accounts, live replies, and the moderation tools the community already knows.

          A few things we care about:

          - Links that keep working when a title changes.
          - A feed you can subscribe to in your favorite reader.
          - Drafts that stay out of the public archive.
          - Space for thoughtful responses, not just a reaction count.

          ## An invitation

          This is a working first version, not a finished manifesto. Scroll down, say hello, and tell us what a good community blog should feel like.
        MD
      },
      {
        path: "/the-case-for-writing-in-public",
        title: "The case for writing in public",
        excerpt:
          "Useful writing doesn’t have to be definitive. Sometimes the most valuable thing you can share is the question you are still working through.",
        raw: <<~MD,
          *Demo content for exploring the blog.*

          A polished answer is useful. But a well-framed question can be even more useful, especially when it reaches people who have been thinking about the same thing from another direction.

          ## Leave a little room

          We tend to imagine publishing as the final step: research, draft, polish, publish. In a community, it is often better understood as a midpoint.

          You bring what you have learned. Someone else brings the exception. A third person supplies the example that makes the whole thing click.

          That does not mean publishing carelessly. It means being honest about what is settled and what is still an experiment.

          ## Three questions before publishing

          1. What is the one idea I want a reader to take away?
          2. What would help someone disagree constructively?
          3. Where should the conversation go next?

          The last question is why the replies belong alongside the article. Context matters, and the best follow-up should not disappear into a different system.

          **What have you learned by sharing an unfinished idea?**
        MD
      },
      {
        path: "/keeping-the-web-readable",
        title: "Keeping the web readable",
        excerpt:
          "Permanent links, readable pages, and a good RSS feed are small features with a surprisingly long life.",
        raw: <<~MD,
          *Demo content for exploring the blog.*

          Some web features age beautifully. A link you bookmarked years ago still opens. An RSS reader quietly brings you a new article. A page prints without losing the thing you came to read.

          None of these needs to be complicated.

          ## Start with the document

          The simplest useful representation of an article is still a document: a heading, some paragraphs, and meaningful links.

          ```html
          <article>
            <h1>An idea worth sharing</h1>
            <p>Start with the words.</p>
          </article>
          ```

          Add interaction where it helps, rather than making the words depend on it.

          ## Respect the address

          Titles evolve. Categories change. A permanent link should survive both. If an address really must change, leave a redirect behind for the people who trusted the old one.

          ## Let readers choose

          Visit the site, subscribe to the feed, or join the discussion. A good publication does not insist that everyone reads in the same way.
        MD
      },
    ]
    examples.each_with_index do |example, index|
      next if Blog::Path.exists?(path: example[:path])
      post =
        PostCreator.create!(
          admin,
          title: example[:title],
          raw: example[:raw],
          category: drafts.id,
          skip_rate_limits: true,
        )
      publication = Blog::Publication.for_topic(post.topic)
      publication.save_metadata!(
        admin,
        path: example[:path],
        excerpt: example[:excerpt],
        featured: example[:featured] || false,
        published_at: index.days.ago,
      )
      publication.publish!(admin)
    end
    unless Topic.where(category_id: drafts.id, title: "Draft: what we are building next").exists?
      PostCreator.create!(
        admin,
        category: drafts.id,
        title: "Draft: what we are building next",
        skip_rate_limits: true,
        raw: <<~MD,
        This is a private demo draft. It is not listed on the public blog.

        ## The next chapter

        Use the edit button to make this your own. The normal Discourse composer provides uploads, Markdown, rich text, revisions, and autosave.

        When you are ready, use the publication panel above this post. Open **Article settings** to give the article a short excerpt and a permanent path, preview it, then choose **Publish**.

        Publishing copies the approved article into a new public discussion in the blog category. This topic and its replies stay private, so editorial notes here are never published.
      MD
      )
    end
    replies = {
      "/a-small-home-for-big-ideas" => [
        [
          :first_reader,
          "The separation feels right: a quiet article first, then a real conversation. I would love to see more behind-the-scenes posts here.",
        ],
        [
          :admin,
          "Exactly the idea. Try replying here from the blog — this is the same discussion you can open in Discuss.",
        ],
        [
          :first_reader,
          "The quiet reading experience is what sold me. I like being able to finish an article before seeing the conversation, rather than having a sidebar compete for attention.",
        ],
        [
          :second_reader,
          "One thing I would love to see here: follow-up posts that collect what people learned in the comments. Sometimes the best example arrives a week after the original article.",
        ],
        [
          :admin,
          "That is exactly the kind of loop we want: publish an idea, listen, then write something better. A monthly roundup of community discoveries would be a good place to start.",
        ],
      ],
      "/the-case-for-writing-in-public" => [
        [
          :first_reader,
          "The hardest part for me is deciding when something is ready to share. I have started calling my early posts field notes rather than guides. That small change makes it much easier to admit what I do not know yet.",
        ],
        [
          :second_reader,
          "I tried this with a project journal last month. A short post about a failed approach got more useful responses than my polished launch announcement. People could actually see where help was needed.",
        ],
        [
          :admin,
          "A useful rule of thumb: share one concrete observation and one honest question. It gives readers something to respond to without making the post feel unfinished. What did you change after that feedback?",
        ],
        [
          :second_reader,
          "We simplified the onboarding flow instead of adding another help page. Someone pointed out that our instructions were explaining a problem we could just remove. I would not have spotted that on my own.",
        ],
      ],
      "/keeping-the-web-readable" => [
        [
          :second_reader,
          "Thank you for keeping RSS in the picture. My feed reader is still the only place where I get to choose what to read without an algorithm rearranging everything.",
        ],
        [
          :first_reader,
          "Readable also means usable on a slow connection. I opened this on the train and the article was there before the discussion loaded. That is a small detail that makes a big difference.",
        ],
        [
          :admin,
          "The article should never have to wait for the comments application. The same goes for permanent links: changing a headline should not break a bookmark someone saved six months ago.",
        ],
        [
          :first_reader,
          "My other vote is for descriptive links. A sentence that tells me where a link goes is much more useful than a row of identical read-more buttons, especially with a screen reader.",
        ],
      ],
    }

    first_reader, second_reader = Blog::DemoUsers.members(2)
    first_reader ||= admin
    second_reader ||= first_reader
    authors = { admin:, first_reader:, second_reader: }

    replies.each do |path, conversation|
      discussion = Blog::Publication.publicly_visible.find_by(path: path)&.discussion_topic
      next if !discussion
      conversation.each do |role, text|
        raw = "#{text}\n\n*Sample conversation for the demo blog.*"
        # Authors are random on each run, so match on the text alone.
        next if discussion.posts.exists?(raw: raw)

        PostCreator.create!(
          authors.fetch(role),
          topic_id: discussion.id,
          raw: raw,
          skip_rate_limits: true,
        )
      end
    end

    puts "Blog: #{Blog::Configuration.origin}"
    puts "Editor: #{Discourse.base_url}/blog/editor"
    puts "Categories: Blog=#{blog.id}, private drafts=#{drafts.id}"
  end
end
