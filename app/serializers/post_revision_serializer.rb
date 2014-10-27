class PostRevisionSerializer < ApplicationSerializer

  attributes :created_at,
             :post_id,
             # which revision is hidden
             :previous_hidden,
             :current_hidden,
             # dynamic & based on the current scope
             :first_revision,
             :previous_revision,
             :current_revision,
             :next_revision,
             :last_revision,
             # used for display
             :current_version,
             :version_count,
             # from the user
             :username,
             :display_username,
             :avatar_template,
             # all the changes
             :edit_reason,
             :body_changes,
             :title_changes,
             :category_changes,
             :user_changes,
             :wiki_changes,
             :post_type_changes

  def previous_hidden
    previous["hidden"]
  end

  def current_hidden
    current["hidden"]
  end

  def first_revision
    revisions.first["revision"]
  end

  def previous_revision
    @previous_revision ||= revisions.select { |r| r["revision"] >= first_revision }
                                    .select { |r| r["revision"] < current_revision }
                                    .last.try(:[], "revision")
  end

  def current_revision
    object.number
  end

  def next_revision
    @next_revision ||= revisions.select { |r| r["revision"] <= last_revision }
                                .select { |r| r["revision"] > current_revision }
                                .first.try(:[], "revision")
  end

  def last_revision
    @last_revision ||= revisions.select { |r| r["revision"] <= post.version }.last["revision"]
  end

  def current_version
    @current_version ||= revisions.select { |r| r["revision"] <= current_revision }.count + 1
  end

  def version_count
    revisions.count
  end

  def username
    user.username_lower
  end

  def display_username
    user.username
  end

  def avatar_template
    user.avatar_template
  end

  def edit_reason
    # only show 'edit_reason' when revisions are consecutive
    current["edit_reason"] if scope.can_view_hidden_post_revisions? ||
                              current["revision"] == previous["revision"] + 1
  end

  def body_changes
    cooked_diff = DiscourseDiff.new(previous["cooked"], current["cooked"])
    raw_diff = DiscourseDiff.new(previous["raw"], current["raw"])

    {
      inline: cooked_diff.inline_html,
      side_by_side: cooked_diff.side_by_side_html,
      side_by_side_markdown: raw_diff.side_by_side_markdown
    }
  end

  def title_changes
    prev = "<div>#{CGI::escapeHTML(previous["title"])}</div>"
    cur = "<div>#{CGI::escapeHTML(current["title"])}</div>"
    return if prev == cur

    diff = DiscourseDiff.new(prev, cur)

    {
      inline: diff.inline_html,
      side_by_side: diff.side_by_side_html
    }
  end

  def category_changes
    prev = previous["category_id"]
    cur = current["category_id"]
    return if prev == cur

    {
      previous: prev,
      current: cur,
    }
  end

  def user_changes
    prev = previous["user_id"]
    cur = current["user_id"]
    return if prev == cur

    # if stuff is messed up, default to system
    previous = User.find_by(id: prev) || Discourse.system_user
    current = User.find_by(id: cur) || Discourse.system_user

    {
        previous: {
          username: previous.username_lower,
          display_username: previous.username,
          avatar_template: previous.avatar_template
        },
        current: {
          username: current.username_lower,
          display_username: current.username,
          avatar_template: current.avatar_template
        }
    }
  end

  def wiki_changes
    prev = previous["wiki"]
    cur = current["wiki"]
    return if prev == cur

    {
        previous: prev,
        current: cur,
    }
  end

  def post_type_changes
    prev = previous["post_type"]
    cur = current["post_type"]
    return if prev == cur

    {
        previous: prev,
        current: cur,
    }
  end

  protected

    def post
      @post ||= object.post
    end

    def topic
      @topic ||= object.post.topic
    end

    def revisions
      @revisions ||= all_revisions.select { |r| scope.can_view_hidden_post_revisions? || !r["hidden"] }
    end

    def all_revisions
      return @all_revisions if @all_revisions

      post_revisions = PostRevision.where(post_id: object.post_id).order(:number).to_a
      post_revisions << PostRevision.new(
        number: post_revisions.last.number + 1,
        hidden: post.hidden,
        modifications: {
          "raw" => [post.raw],
          "cooked" => [post.cooked],
          "edit_reason" => [post.edit_reason],
          "wiki" => [post.wiki],
          "post_type" => [post.post_type],
          "user_id" => [post.user_id],
          "title" => [topic.title],
          "category_id" => [topic.category_id],
        }
      )

      @all_revisions = []

      # backtrack
      post_revisions.each do |pr|
        revision = HashWithIndifferentAccess.new
        revision[:revision] = pr.number
        revision[:hidden] = pr.hidden

        pr.modifications.keys.each do |field|
          revision[field] = pr.modifications[field][0]
        end

        @all_revisions << revision
      end

      # waterfall
      (@all_revisions.count - 1).downto(1).each do |r|
        cur = @all_revisions[r]
        prev = @all_revisions[r - 1]

        cur.keys.each do |field|
          prev[field] = prev.has_key?(field) ? prev[field] : cur[field]
        end
      end

      @all_revisions
    end

    def previous
      @previous ||= revisions.select { |r| r["revision"] <= current_revision }.last
    end

    def current
      @current ||= revisions.select { |r| r["revision"] > current_revision }.first
    end

    def user
      # if stuff goes pear shape attribute to system
      object.user || Discourse.system_user
    end

end
