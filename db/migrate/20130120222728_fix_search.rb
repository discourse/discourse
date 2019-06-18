# frozen_string_literal: true

class FixSearch < ActiveRecord::Migration[4.2]
  def up
    execute 'drop index idx_search_thread'
    execute 'drop index idx_search_user'

    execute 'create table posts_search (id integer not null primary key, search_data tsvector)'
    execute 'create table users_search (id integer not null primary key, search_data tsvector)'
    execute 'create table categories_search (id integer not null primary key, search_data tsvector)'

    execute 'create index idx_search_post on posts_search using gin(search_data) '
    execute 'create index idx_search_user on users_search using gin(search_data) '
    execute 'create index idx_search_category on categories_search using gin(search_data) '
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
