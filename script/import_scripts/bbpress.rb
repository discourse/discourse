# `dropdb bbpress`
# `createdb bbpress`
# `bundle exec rake db:migrate`

BB_PRESS_DB = "import"

require 'mysql2'

@client = Mysql2::Client.new(
  host: "localhost",
  username: "root",
  password: "password",
  :database => BB_PRESS_DB
)


require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")
SiteSetting.email_domains_blacklist = ''
RateLimiter.disable

def create_admin
  User.new.tap { |admin|
    admin.email = "sam.saffron@gmail.com"
    admin.username = "sam"
    admin.password = SecureRandom.uuid
    admin.save
    admin.grant_admin!
    admin.change_trust_level!(:regular)
    admin.email_tokens.update_all(confirmed: true)
  }
end

def create_user(opts, import_id)
  opts[:name] = User.suggest_name(opts[:name] || opts[:email])
  opts[:username] = UserNameSuggester.suggest(opts[:username] || opts[:name] || opts[:email])
  opts[:email] = opts[:email].downcase

  u = User.new(opts)
  u.custom_fields["import_id"] = import_id

  u.save!
  u

rescue
  # try based on email
  u = User.find_by(email: opts[:email].downcase)
  u.custom_fields["import_id"] = import_id
  u.save!
  u
end


def create_post(opts)

  user = User.find(opts[:user_id])
  opts = opts.merge(skip_validations: true)

  PostCreator.create(user, opts)
end


results = @client.query("
                        select  ID,
                                user_login username,
                                display_name name,
                                user_url website,
                                user_email email,
                                user_registered created_at
                        from wp_users where spam = 0 and deleted = 0").to_a


users = {}

UserCustomField.where(name: 'import_id')
                .pluck(:user_id, :value)
                .each do |user_id, import_id|
  users[import_id.to_i] = user_id
end

skipped = 0
results.delete_if do |u|
  skipped+= 1 if users[u["ID"]]
end

puts "Importing #{results.length} users (skipped #{skipped})"

i = 0
results.each do |u|
  putc "." if ((i+=1)%10) == 0

  id = u.delete("ID")
  users[id] = create_user(ActiveSupport::HashWithIndifferentAccess.new(u), id).id
end



results = @client.query("
                       select ID, post_name from wp_posts where post_type = 'forum'
                        ").to_a

categories={}

CategoryCustomField.where(name: 'import_id')
                  .pluck(:category_id, :value)
                .each do |category_id, import_id|
  categories[import_id.to_i] = category_id
end


skipped = 0
results.delete_if do |u|
  skipped+= 1 if categories[u["ID"]]
end

puts
puts "Importing #{results.length} categories (skipped #{skipped})"

results.each do |c|
  c["post_name"] = "unknown" if c["post_name"].blank?
  category = Category.new(name: c["post_name"], user_id: -1)
  category.custom_fields["import_id"] = c["ID"]
  category.save!
  categories[c["ID"]] = category.id
end

results = @client.query("
                       select ID,
                              post_author,
                              post_date,
                              post_content,
                              post_title,
                              post_type,
                              post_parent
                       from wp_posts
                       where post_status <> 'spam'
                          and post_type in ('topic', 'reply')
                       order by ID
                        ").to_a

posts={}

PostCustomField.where(name: 'import_id')
                .pluck(:post_id, :value)
                .each do |post_id, import_id|
  posts[import_id.to_i] = post_id
end


skipped = 0
results.delete_if do |u|
  skipped+= 1 if posts[u["ID"]]
end

puts "Importing #{results.length} posts (skipped #{skipped})"

topic_lookup = {}
Post.pluck(:id, :topic_id, :post_number).each do |p,t,n|
  topic_lookup[p] = {topic_id: t, post_number: n}
end

i = 0
results.each do |post|
  putc "." if ((i+=1)%10) == 0

  mapped = {}

  mapped[:user_id] = users[post["post_author"]]
  mapped[:raw] = post["post_content"]
  mapped[:created_at] = post["post_date"]

  if post["post_type"] == "topic"
    mapped[:category] = categories[post["post_parent"]]
    mapped[:title] = CGI.unescapeHTML post["post_title"]
  else
    parent_id = posts[post["post_parent"]]
    parent = topic_lookup[parent_id]
    unless parent
      puts; puts "Skipping #{post["ID"]}: #{post["post_content"][0..40]}"
      next
    end
    mapped[:topic_id] = parent[:topic_id]
    mapped[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
  end

  mapped[:custom_fields] = {import_id: post["ID"]}

  d_post = create_post(mapped)
  posts[post["ID"]] = d_post.id
  topic_lookup[d_post.id] = {post_number: d_post.post_number, topic_id: d_post.topic_id}

end

Post.exec_sql("update topics t set bumped_at = (select max(created_at) from posts where topic_id = t.id)")
