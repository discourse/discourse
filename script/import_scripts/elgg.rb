# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Elgg < ImportScripts::Base
  BATCH_SIZE = 1000

  def initialize
    super

    @client =
      Mysql2::Client.new(host: "127.0.0.1", port: "3306", username: "", database: "", password: "")

    SiteSetting.max_username_length = 50
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
  end

  def create_avatar(user, guid)
    puts "#{@path}"
    # Put your avatar at the root of discourse in this folder:
    path_prefix = "import/data/www/"
    # https://github.com/Elgg/Elgg/blob/2fc9c1910a9169bbe4010026c61d8e41a5b56239/engine/classes/ElggDiskFilestore.php#L24
    # 	const BUCKET_SIZE = 5000;
    bucket_size = 5000
    #https://github.com/Elgg/Elgg/blob/0e7eedceaa96151f0cea0625b34f78d3d96a3e14/engine/classes/Elgg/EntityDirLocator.php#L80
    # 	return (int) max(floor($guid / $bucket_size) * $bucket_size, 1);
    bucket_id = [guid / bucket_size * bucket_size, 1].max

    avatar_path = File.join(path_prefix, bucket_id.to_s, "/#{guid}/profile/#{guid}master.jpg")
    @uploader.create_avatar(user, avatar_path) if File.exist?(avatar_path)
  end

  def grant_admin(user, is_admin)
    if is_admin == "yes"
      puts "", "#{user.username} is granted admin!"
      user.grant_admin!
    end
  end

  def import_users
    puts "", "importing users..."

    last_user_id = -1
    total_users =
      mysql_query("select count(*) from elgg_users_entity where banned='no'").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL).to_a
        select eue.guid, eue.username, eue.name, eue.email, eue.admin,
        max(case when ems1.string='cae_structure' then ems2.string  end)cae_structure,
        max(case when ems1.string='location' then ems2.string  end)location,
        max(case when ems1.string='validated' then ems2.string  end)validated,
        max(case when ems1.string='briefdescription' then ems2.string  end)briefdescription,
        max(case when ems1.string='website' then ems2.string  end)website
        from elgg_users_entity eue
        join elgg_metadata em on em.entity_guid = eue.guid
        join elgg_metastrings ems1 on ems1.id = em.name_id
        join elgg_metastrings ems2 on ems2.id = em.value_id
        where
        eue.banned='no'
        and eue.guid > #{last_user_id}
        group by eue.guid
        LIMIT #{BATCH_SIZE}
      SQL

      break if users.empty?

      last_user_id = users[-1]["guid"]
      user_ids = users.map { |u| u["guid"].to_i }

      next if all_records_exist?(:users, user_ids)

      user_ids_sql = user_ids.join(",")

      create_users(users, total: total_users, offset: offset) do |u|
        if u["validated"] = 1
          {
            id: u["guid"].to_i,
            username: u["username"],
            location: u["location"],
            email: u["email"].downcase,
            name: u["name"],
            website: u["website"],
            bio_raw: u["briefdescription"].to_s + " " + u["cae_structure"].to_s,
            post_create_action:
              proc do |user|
                create_avatar(user, u["guid"])
                #add_user_to_group(user, u["cae_structure"])
                grant_admin(user, u["admin"])
              end,
          }
        end
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("select guid, name, description from elgg_groups_entity")

    create_categories(categories) do |c|
      {
        id: c["guid"],
        name: CGI.unescapeHTML(c["name"]),
        description: CGI.unescapeHTML(c["description"]),
      }
    end
  end

  def import_topics
    puts "", "creating topics"

    total_count =
      mysql_query("select count(*) count from elgg_entities where subtype = 32;").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
        SELECT
        ee.guid id,
        owner_guid user_id,
        container_guid category_id,
        time_created created_at,
        title,
        description raw
        FROM elgg_entities ee
        JOIN elgg_objects_entity eoe on ee.guid = eoe.guid
        WHERE
        subtype = 32
        ORDER BY ee.guid
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ",
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m["id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        {
          id: m["id"],
          user_id: user_id_from_imported_user_id(m["user_id"]) || -1,
          raw: CGI.unescapeHTML(m["raw"]),
          created_at: Time.zone.at(m["created_at"]),
          category: category_id_from_imported_category_id(m["category_id"]),
          title: CGI.unescapeHTML(m["title"]),
          post_create_action:
            proc do |post|
              tag_names =
                mysql_query(
                  "
              select ms.string
              from elgg_metadata md
              join elgg_metastrings ms on md.value_id = ms.id
              where name_id = 43
              and entity_guid = #{m["id"]};
            ",
                ).map { |tag| tag["string"] }
              DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names)
            end,
        }
      end
    end
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def import_posts
    puts "", "creating posts"

    total_count =
      mysql_query("SELECT count(*) count FROM elgg_entities WHERE subtype = 42").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
        SELECT
        ee.guid id,
        container_guid topic_id,
        owner_guid user_id,
        description raw,
        time_created created_at
        FROM elgg_entities ee
        JOIN elgg_objects_entity eoe ON ee.guid = eoe.guid
        WHERE subtype = 42
        ORDER BY ee.guid
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ",
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m["id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        {
          id: m["id"],
          user_id: user_id_from_imported_user_id(m["user_id"]) || -1,
          topic_id: topic_lookup_from_imported_post_id(m["topic_id"])[:topic_id],
          raw: CGI.unescapeHTML(m["raw"]),
          created_at: Time.zone.at(m["created_at"]),
        }
      end
    end
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::Elgg.new.perform
