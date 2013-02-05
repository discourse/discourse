# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120809201855) do

  create_table "actions", :force => true do |t|
    t.integer  "action_type",            :null => false
    t.integer  "user_id",                :null => false
    t.integer  "target_forum_thread_id"
    t.integer  "target_post_id"
    t.integer  "target_user_id"
    t.integer  "acting_user_id"
    t.datetime "created_at",             :null => false
    t.datetime "updated_at",             :null => false
  end

  add_index "actions", ["acting_user_id"], :name => "index_actions_on_acting_user_id"
  add_index "actions", ["user_id", "action_type"], :name => "index_actions_on_user_id_and_action_type"

  create_table "categories", :force => true do |t|
    t.string   "name",                 :limit => 50,                       :null => false
    t.string   "color",                :limit => 6,  :default => "AB9364", :null => false
    t.integer  "forum_thread_id"
    t.integer  "top1_forum_thread_id"
    t.integer  "top2_forum_thread_id"
    t.integer  "top1_user_id"
    t.integer  "top2_user_id"
    t.integer  "forum_thread_count",                 :default => 0,        :null => false
    t.datetime "created_at",                                               :null => false
    t.datetime "updated_at",                                               :null => false
    t.integer  "user_id",                                                  :null => false
    t.integer  "threads_year"
    t.integer  "threads_month"
    t.integer  "threads_week"
  end

  add_index "categories", ["forum_thread_count"], :name => "index_categories_on_forum_thread_count"
  add_index "categories", ["name"], :name => "index_categories_on_name", :unique => true

  create_table "category_featured_threads", :id => false, :force => true do |t|
    t.integer  "category_id",     :null => false
    t.integer  "forum_thread_id", :null => false
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "category_featured_threads", ["category_id", "forum_thread_id"], :name => "cat_featured_threads", :unique => true

  create_table "expression_types", :id => false, :force => true do |t|
    t.string   "name",             :limit => 50,                     :null => false
    t.string   "long_form",        :limit => 100,                    :null => false
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
    t.boolean  "flag",                            :default => false
    t.text     "description"
    t.integer  "expression_index"
    t.string   "icon",             :limit => 20
  end

  add_index "expression_types", ["expression_index"], :name => "index_expression_types_on_expression_index", :unique => true
  add_index "expression_types", ["name"], :name => "index_expression_types_on_name", :unique => true

  create_table "expressions", :id => false, :force => true do |t|
    t.integer  "post_id",          :null => false
    t.integer  "expression_index", :null => false
    t.integer  "user_id",          :null => false
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  add_index "expressions", ["post_id", "expression_index", "user_id"], :name => "unique_by_user", :unique => true

  create_table "forum_thread_links", :force => true do |t|
    t.integer  "forum_thread_id",                                        :null => false
    t.integer  "post_id"
    t.integer  "user_id",                                                :null => false
    t.string   "url",                  :limit => 500,                    :null => false
    t.string   "domain",               :limit => 100,                    :null => false
    t.boolean  "internal",                            :default => false, :null => false
    t.integer  "link_forum_thread_id"
    t.datetime "created_at",                                             :null => false
    t.datetime "updated_at",                                             :null => false
    t.boolean  "reflection",                          :default => false
  end

  add_index "forum_thread_links", ["forum_thread_id"], :name => "index_forum_thread_links_on_forum_thread_id"

  create_table "forum_thread_users", :id => false, :force => true do |t|
    t.integer "user_id",                                  :null => false
    t.integer "forum_thread_id",                          :null => false
    t.boolean "starred",               :default => false, :null => false
    t.boolean "posted",                :default => false, :null => false
    t.integer "last_read_post_number", :default => 1,     :null => false
    t.integer "seen_post_count"
  end

  add_index "forum_thread_users", ["forum_thread_id", "user_id"], :name => "index_forum_thread_users_on_forum_thread_id_and_user_id", :unique => true

  create_table "forum_threads", :force => true do |t|
    t.string   "title",                                 :null => false
    t.datetime "last_posted_at"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.integer  "views",               :default => 0,    :null => false
    t.integer  "posts_count",         :default => 0,    :null => false
    t.integer  "user_id",                               :null => false
    t.integer  "last_post_user_id",                     :null => false
    t.integer  "reply_count",         :default => 0,    :null => false
    t.integer  "featured_user1_id"
    t.integer  "featured_user2_id"
    t.integer  "featured_user3_id"
    t.integer  "avg_time"
    t.datetime "deleted_at"
    t.integer  "highest_post_number", :default => 0,    :null => false
    t.string   "image_url"
    t.integer  "expression1_count",   :default => 0,    :null => false
    t.integer  "expression2_count",   :default => 0,    :null => false
    t.integer  "expression3_count",   :default => 0,    :null => false
    t.integer  "expression4_count",   :default => 0,    :null => false
    t.integer  "expression5_count",   :default => 0,    :null => false
    t.integer  "incoming_link_count", :default => 0,    :null => false
    t.integer  "bookmark_count",      :default => 0,    :null => false
    t.integer  "star_count",          :default => 0,    :null => false
    t.integer  "category_id"
    t.boolean  "visible",             :default => true, :null => false
  end

  add_index "forum_threads", ["last_posted_at"], :name => "index_forum_threads_on_last_posted_at"

  create_table "incoming_links", :force => true do |t|
    t.string   "url",             :limit => 1000, :null => false
    t.string   "referer",         :limit => 1000, :null => false
    t.string   "domain",          :limit => 100,  :null => false
    t.integer  "forum_thread_id"
    t.integer  "post_number"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
  end

  add_index "incoming_links", ["forum_thread_id", "post_number"], :name => "incoming_index"

  create_table "message_bus", :force => true do |t|
    t.string   "name"
    t.string   "context"
    t.text     "data"
    t.datetime "created_at"
  end

  add_index "message_bus", ["created_at"], :name => "index_message_bus_on_created_at"

  create_table "notifications", :force => true do |t|
    t.integer  "notification_type",                    :null => false
    t.integer  "user_id",                              :null => false
    t.string   "data",                                 :null => false
    t.boolean  "read",              :default => false, :null => false
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
    t.integer  "forum_thread_id"
    t.integer  "post_number"
  end

  add_index "notifications", ["user_id", "created_at"], :name => "index_notifications_on_user_id_and_created_at"

  create_table "post_action_types", :id => false, :force => true do |t|
    t.integer  "id",                                            :null => false
    t.string   "name",        :limit => 50,                     :null => false
    t.string   "long_form",   :limit => 100,                    :null => false
    t.boolean  "is_flag",                    :default => false, :null => false
    t.text     "description"
    t.string   "icon",        :limit => 20
    t.datetime "created_at",                                    :null => false
    t.datetime "updated_at",                                    :null => false
  end

  create_table "post_actions", :force => true do |t|
    t.integer  "post_id",             :null => false
    t.integer  "user_id",             :null => false
    t.integer  "post_action_type_id", :null => false
    t.datetime "deleted_at"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  add_index "post_actions", ["post_id"], :name => "index_post_actions_on_post_id"
  add_index "post_actions", ["user_id", "post_action_type_id", "post_id"], :name => "idx_unique_actions", :unique => true

  create_table "post_replies", :id => false, :force => true do |t|
    t.integer  "post_id"
    t.integer  "reply_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "post_replies", ["post_id", "reply_id"], :name => "index_post_replies_on_post_id_and_reply_id", :unique => true

  create_table "post_timings", :id => false, :force => true do |t|
    t.integer "forum_thread_id", :null => false
    t.integer "post_number",     :null => false
    t.integer "user_id",         :null => false
    t.integer "msecs",           :null => false
  end

  add_index "post_timings", ["forum_thread_id", "post_number", "user_id"], :name => "post_timings_unique", :unique => true
  add_index "post_timings", ["forum_thread_id", "post_number"], :name => "post_timings_summary"

  create_table "posts", :force => true do |t|
    t.integer  "user_id",                                :null => false
    t.integer  "forum_thread_id",                        :null => false
    t.integer  "post_number",                            :null => false
    t.text     "raw",                                    :null => false
    t.text     "cooked",                                 :null => false
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "reply_to_post_number"
    t.integer  "cached_version",          :default => 1, :null => false
    t.integer  "reply_count",             :default => 0, :null => false
    t.integer  "quote_count",             :default => 0, :null => false
    t.integer  "reply_below_post_number"
    t.datetime "deleted_at"
    t.integer  "expression1_count",       :default => 0, :null => false
    t.integer  "expression2_count",       :default => 0, :null => false
    t.integer  "expression3_count",       :default => 0, :null => false
    t.integer  "expression4_count",       :default => 0, :null => false
    t.integer  "expression5_count",       :default => 0, :null => false
    t.integer  "incoming_link_count",     :default => 0, :null => false
    t.integer  "bookmark_count",          :default => 0, :null => false
    t.integer  "avg_time"
    t.float    "score"
    t.integer  "views",                   :default => 0, :null => false
  end

  add_index "posts", ["forum_thread_id", "post_number"], :name => "index_posts_on_forum_thread_id_and_post_number"
  add_index "posts", ["reply_to_post_number"], :name => "index_posts_on_reply_to_post_number"
  add_index "posts", ["user_id"], :name => "index_posts_on_user_id"

  create_table "site_settings", :force => true do |t|
    t.string   "name",        :null => false
    t.text     "description", :null => false
    t.integer  "data_type",   :null => false
    t.text     "value"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "uploads", :force => true do |t|
    t.integer  "user_id",           :null => false
    t.integer  "forum_thread_id",   :null => false
    t.string   "original_filename", :null => false
    t.integer  "filesize",          :null => false
    t.integer  "width"
    t.integer  "height"
    t.string   "url",               :null => false
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "uploads", ["forum_thread_id"], :name => "index_uploads_on_forum_thread_id"
  add_index "uploads", ["user_id"], :name => "index_uploads_on_user_id"

  create_table "user_open_ids", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.string   "email",      :null => false
    t.string   "url",        :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.boolean  "active",     :null => false
  end

  add_index "user_open_ids", ["url"], :name => "index_user_open_ids_on_url"

  create_table "users", :force => true do |t|
    t.string   "username",             :limit => 20,                     :null => false
    t.string   "avatar_url",                                             :null => false
    t.datetime "created_at",                                             :null => false
    t.datetime "updated_at",                                             :null => false
    t.string   "name"
    t.text     "bio"
    t.integer  "seen_notificaiton_id",                :default => 0,     :null => false
    t.datetime "last_posted_at"
    t.string   "email",                :limit => 256,                    :null => false
    t.string   "password_hash",        :limit => 64
    t.string   "salt",                 :limit => 32
    t.boolean  "active"
    t.string   "username_lower",       :limit => 20,                     :null => false
    t.string   "auth_token",           :limit => 32
    t.datetime "last_seen_at"
    t.string   "website"
    t.string   "email_token",          :limit => 32
    t.boolean  "admin",                               :default => false, :null => false
    t.boolean  "moderator",                           :default => false, :null => false
  end

  add_index "users", ["auth_token"], :name => "index_users_on_auth_token"
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["last_posted_at"], :name => "index_users_on_last_posted_at"
  add_index "users", ["username"], :name => "index_users_on_username", :unique => true
  add_index "users", ["username_lower"], :name => "index_users_on_username_lower", :unique => true

  create_table "versions", :force => true do |t|
    t.integer  "versioned_id"
    t.string   "versioned_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "user_name"
    t.text     "modifications"
    t.integer  "number"
    t.integer  "reverted_from"
    t.string   "tag"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "versions", ["created_at"], :name => "index_versions_on_created_at"
  add_index "versions", ["number"], :name => "index_versions_on_number"
  add_index "versions", ["tag"], :name => "index_versions_on_tag"
  add_index "versions", ["user_id", "user_type"], :name => "index_versions_on_user_id_and_user_type"
  add_index "versions", ["user_name"], :name => "index_versions_on_user_name"
  add_index "versions", ["versioned_id", "versioned_type"], :name => "index_versions_on_versioned_id_and_versioned_type"

  create_table "views", :id => false, :force => true do |t|
    t.integer  "parent_id",                 :null => false
    t.string   "parent_type", :limit => 50, :null => false
    t.integer  "ip",          :limit => 8,  :null => false
    t.datetime "viewed_at",                 :null => false
    t.integer  "user_id"
  end

  add_index "views", ["parent_id", "parent_type", "ip", "viewed_at"], :name => "unique_views", :unique => true
  add_index "views", ["parent_id", "parent_type"], :name => "index_views_on_parent_id_and_parent_type"

end
