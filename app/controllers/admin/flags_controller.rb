class Admin::FlagsController < Admin::AdminController
  def index

    sql = SqlBuilder.new "select p.id, t.title, p.cooked, p.user_id, p.topic_id, p.post_number, p.hidden, t.visible topic_visible
from posts p
join topics t on t.id = topic_id
join (
  select
    post_id,
    count(*) as cnt,
    max(created_at) max,
    min(created_at) min
    from post_actions
    /*where2*/
    group by post_id
) as a on a.post_id = p.id
/*where*/
/*order_by*/
limit 100
"

    sql.where2 "post_action_type_id in (:flag_types)", flag_types: PostActionType.notify_flag_types.values


    # it may make sense to add a view that shows flags on deleted posts,
    # we don't clear the flags on post deletion, just supress counts
    #   they may have deleted_at on the action not set
    if params[:filter] == 'old'
      sql.where2 "deleted_at is not null"
    else
      sql.where "p.deleted_at is null and t.deleted_at is null"
      sql.where2 "deleted_at is null"
    end

    if params[:filter] == 'old'
      sql.order_by "max desc"
    else
      sql.order_by "cnt desc, max asc"
    end

    posts = sql.exec.to_a

    if posts.length == 0
      render json: {users: [], posts: []}
      return
    end

    map = {}
    users = Set.new

    posts.each{ |p|
      users << p["user_id"]
      p["excerpt"] = Post.excerpt(p["cooked"])
      p.delete "cooked"
      p[:topic_slug] = Slug.for(p["title"])
      map[p["id"]] = p
    }

    sql = SqlBuilder.new "select a.id, a.user_id, post_action_type_id, a.created_at, post_id, a.message, p.topic_id, t.slug
from post_actions a
left join posts p on p.id = related_post_id
left join topics t on t.id = p.topic_id
/*where*/
"
    sql.where("post_action_type_id in (:flag_types)", flag_types: PostActionType.notify_flag_types.values)
    sql.where("post_id in (:posts)", posts: posts.map{|p| p["id"].to_i})

    if params[:filter] == 'old'
      sql.where('a.deleted_at is not null')
    else
      sql.where('a.deleted_at is null')
    end

    sql.exec.each do |action|
      action["permalink"] = Topic.url(action["topic_id"],action["slug"]) if action["slug"].present?
      p = map[action["post_id"]]
      p[:post_actions] ||= []
      p[:post_actions] << action

      users << action["user_id"]
    end

    sql =
"select id, username, name, email from users
where id in (?)"

    users = User.exec_sql(sql, users.to_a).to_a

    users.each { |u|
      u["avatar_template"] = User.avatar_template(u["email"])
      u.delete("email")
    }

    render json: MultiJson.dump({users: users, posts: posts})
  end

  def clear
    p = Post.find(params[:id])
    PostAction.clear_flags!(p, current_user.id)
    p.hidden = false
    p.hidden_reason_id = nil
    p.save
    render nothing: true
  end
end
