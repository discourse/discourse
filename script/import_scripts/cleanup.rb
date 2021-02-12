require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "kunena"
  DB_USER ||= ENV['DB_USER'] || "kunena"
  DB_PW   ||= ENV['DB_PW'] || "kunena"
  KUNENA_PREFIX ||= ENV['KUNENA_PREFIX'] || "jos_" # "iff_" sometimes
  IMAGE_PREFIX ||= ENV['IMAGE_PREFIX'] || "http://EXAMPLE.com/media/kunena/attachments"
  PARENT_FIELD ||= ENV['PARENT_FIELD'] || "parent_id" # "parent" in some versions

@client = Mysql2::Client.new(
    host: DB_HOST,
    username: DB_USER,
    password: DB_PW,
    database: DB_NAME
  )

# Nej for den er også creater af alle "Welcome" - User.where(id: -1).update_all(username: "Slettet bruger", name: "Slettet bruger")

def set_group_owners(group)
    n11 = User.find_by_username("n11")
    babylai = User.find_by_username("babylai")
    storebror = User.find_by_username("storebror")
    babyfox = User.find_by_username("babyfox")
    if n11 != nil
        GroupUser.create_or_find_by(group_id: group.id, user_id: n11.id, owner: true)
    end
    GroupUser.create_or_find_by(group_id: group.id, user_id: babylai.id, owner: true)
    GroupUser.create_or_find_by(group_id: group.id, user_id: storebror.id, owner: true)
    GroupUser.create_or_find_by(group_id: group.id, user_id: babyfox.id, owner: true)
end

def create_groups
    over15 = Group.find_by(name: "Over15")
    if over15 == nil
        over15 = Group.create_or_find_by(name: "Over15")
        over15.full_name = "Over 15 år"
        over15.membership_request_template = "For at blive medlem skal din fødselsdato fremgå af din profil."
        over15.public_exit = true
        over15.visibility_level = 1
        over15.members_visibility_level = 3
        over15.default_notification_level = 0
        over15.bio_raw = "Denne gruppe giver adgang til 'Kontakt' kategorien"
        over15.save!
        set_group_owners(over15)
        over15.allow_membership_requests = true
        over15.save!
        puts "Created Over15 gruppe"
    end
    puts over15.id
    set_group_owners(over15)

    over18 = Group.find_by(name: "Over18")
    if over18 == nil
        over18 = Group.create_or_find_by(name: "Over18")
        over18.full_name = "Over 18 år"
        over18.membership_request_template = "For at blive medlem skal din fødselsdato fremgå af din profil."
        over18.public_exit = true
        over18.visibility_level = 1
        over18.members_visibility_level = 3
        over18.default_notification_level = 0
        over18.bio_raw = "Denne gruppe giver adgang til kategorier med seksuelt indhold"
        over18.save!
        set_group_owners(over18)
        over18.allow_membership_requests = true
        over18.save!
        puts "Created over18 gruppe"
    end
    puts over18.id

    set_group_owners(over18)

    under20 = Group.find_by(name: "Under20")
    if under20 == nil
        under20 = Group.create_or_find_by(name: "Under20")
        under20.full_name = "Under 20 år"
        under20.membership_request_template = "For at blive medlem skal din fødselsdato fremgå af din profil."
        under20.public_exit = true
        under20.visibility_level = 1
        under20.members_visibility_level = 3
        under20.default_notification_level = 0
        under20.bio_raw = "Denne gruppe giver adgang til kategorien 'Unge'. Der er kun adgang hvis du er under 20 år."
        under20.save!
        set_group_owners(under20)
        under20.allow_membership_requests = true
        under20.save!
        puts "Created under20 gruppe"
    end
    puts under20.id
    set_group_owners(under20)
end

def populate_groups
    puts "fetching group / users data from mysql"
    gruppe = Group.find_by(name: "Under20")
    results = @client.query("SELECT username FROM jos_community_groups_members, jos_users WHERE `groupid` = 3 and id = memberid and approved = 1;", cache_rows: false)
    results.each do |u|
        puts u
        user = User.find_by_username(u['username']) 
        if user !=nil
          gu = GroupUser.create_or_find_by(group_id: gruppe.id, user_id: user.id)
          gu.save
        end
    end

    puts "fetching group / users data from mysql"
    gruppe = Group.find_by(name: "Over18")
    results = @client.query("SELECT distinct username FROM jos_community_groups_members, jos_users WHERE `groupid` in (5, 82, 25, 30, 81, 86, 96, 95) and id = memberid and approved = 1;", cache_rows: false)
    results.each do |u|
        puts u
        user = User.find_by_username(u['username']) 
        if user !=nil
          gu = GroupUser.create_or_find_by(group_id: gruppe.id, user_id: user.id)
          gu.save
        end
    end
end

def create_category(name)
    catcreate = Category.find_by(name: name)
    if catcreate == nil
        catcreate = Category.create_or_find_by(name: name)
        catcreate.user_id = User.find_by_username("System").id
        puts "Created #{name} category"
        catcreate.save!
    end
    catcreate
end

def cleanup_categories
    Category.where(name: "AB Legested").update_all(parent_category_id: nil)

    siteforum = Category.find_by_slug("site-forum")
    if siteforum != nil 
        Category.where(parent_category_id: siteforum.id).update_all(parent_category_id: nil)
        Category.update_stats
        siteforum.delete
    end
    
    purge_and_delete_category(Category.where(name: "Support forum").first)
    purge_and_delete_category(Category.where(name: "Hjælp").first)
    purge_and_delete_category(Category.where(name: "Kommertarer til historier").first)

    hardcorecat = create_category("Hardcore")
    puts hardcorecat
    puts hardcorecat.id
    CategoryGroup.create_or_find_by(group_id: Group.find_by(name: "Over18").id, category_id: hardcorecat.id, permission_type: 1)    
    CategoryGroup.create_or_find_by(group_id: Group.find_by(name: "admins").id, category_id: hardcorecat.id, permission_type: 1)    
    

    abcat = create_category("Ageplay")
    puts abcat.id

    Category.find_by(name: "Age-play - med sex, dominans m.m.").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Potter").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Brugte bleer").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Tisseriet").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Ingen grænser (bummelum)").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Pornografi og sex").update(parent_category_id: hardcorecat.id )
    Category.find_by(name: "Medical kink").update(parent_category_id: hardcorecat.id )

    Category.find_by(name: "Age-play - 12+").update(parent_category_id: abcat.id )
    Category.find_by(name: "Age-play - 5-12 (ingen sex)").update(parent_category_id: abcat.id )
    Category.find_by(name: "Babylege 0-5 (ingen sex)").update(parent_category_id: abcat.id )
    Category.find_by(name: "Babyhjørnet").update(parent_category_id: abcat.id )
#    Category.find_by(name: "Age-play - 12+").update(parent_category_id: abcat.id )
#    Category.find_by(name: "Age-play - 12+").update(parent_category_id: abcat.id )

    merge_and_delete_category(Category.find_by(name: "SM & Dominans"), Category.find_by(name: "Age-play - med sex, dominans m.m."))
    if Category.find_by(name: "SM & Dominans") != nil
        Category.find_by(name: "SM & Dominans").delete
    end

    merge_and_delete_category(Category.find_by(name: "Age-play - med sex, dominans m.m."), Category.find_by(name: "BDSM"))
    if Category.find_by(name: "BDSM") != nil
        Category.find_by(name: "BDSM").delete
    end

    merge_and_delete_category(Category.find_by(name: "Messy"), Category.find_by(name: "Ingen grænser (bummelum)"))
    if Category.find_by(name: "Messy") != nil
      Category.find_by(name: "Messy").delete
    end

    merge_and_delete_category(Category.find_by(name: "Teenforum"), Category.find_by(name: "Ungdomsforum"))
    if Category.find_by(name: "Teenforum") != nil
      Category.find_by(name: "Teenforum").delete
    end

    merge_and_delete_category(Category.find_by(name: "Age-play"), Category.find_by(name: "Ageplay"))

    purge_and_delete_category(Category.where(name: "Artikler - diskussion").first)
    purge_and_delete_category(Category.where(name: "Forum").first)
    purge_and_delete_category(Category.where(name: "Gammelt forum").first)

    if Category.find_by(name: "Om infantilisme") != nil
        Category.find_by(name: "Om infantilisme").update(name: "Information" )
    end

    if Category.find_by(name: "Historier") != nil
        Category.find_by(name: "Historier").update(name: "Historier der skal sorteres", description: "Disse historier bliver redigeret og flyttet efterhånden som staff får tid.", slug: "historier-overforte" )
    end
    histcat = create_category("Historier")
    histcat.update(description: "Historier, noveller m.m. Underkategorier kommer.")
end

def merge_and_delete_category(from, to)
    if from != nil && to != nil
        Topic.where(category_id: from.id).update_all(category_id: to.id)
        Category.update_stats
        if (from.topic_count == 0)
            from.delete
        end
    end
end

def purge_and_delete_category(tobedeleted)
  if tobedeleted != nil
    Topic.where(category_id: tobedeleted.id).destroy_all
    Category.update_stats
    if (tobedeleted.topic_count == 0)
        tobedeleted.delete
    end
  end
end

def set_category_options
  # Set permissions on categories
  gOver18id = Group.find_by(name: "Over18").id
  gAdminid = Group.find_by(name: "admins").id
  cHardcordid = Category.find_by(name: "Hardcore").id
  Category.where(parent_category_id: cHardcordid).each do |c|
    CategoryGroup.where(category_id: c.id).each do |cg|
        cg.delete
    end
    puts "Setting security on " + c.name
    CategoryGroup.create_or_find_by!(category_id: c.id, group_id: gAdminid, permission_type: 1)
    CategoryGroup.create_or_find_by!(category_id: c.id, group_id: gOver18id, permission_type: 1)
    c.read_restricted = true
    c.save!
  end
  CategoryGroup.where(category_id: cHardcordid).each do |cg|
     cg.delete
  end
  CategoryGroup.create_or_find_by!(category_id: cHardcordid, group_id: gAdminid, permission_type: 1)
  CategoryGroup.create_or_find_by!(category_id: cHardcordid, group_id: gOver18id, permission_type: 1)
  Category.find_by(id: cHardcordid).update(read_restricted: true)
  
  cUnge = Category.find_by(name: "Ungdomsforum")
  CategoryGroup.where(category_id: cUnge.id).each do |cg|
    cg.delete
  end
  cUnge.read_restricted = true
  cUnge.description = "Mødested for unge - dvs uynder 20 år. Der er ikke adgang for andre over 20 end admin og moderatorer."
  cUnge.parent_category_id = nil
  cUnge.save!
  CategoryGroup.create_or_find_by!(category_id: cUnge.id, group_id: gAdminid, permission_type: 1)
  CategoryGroup.create_or_find_by!(category_id: cUnge.id, group_id: Group.find_by(name: "Under20").id, permission_type: 1)
 


end

def set_site_settings
    SiteSetting.where(name: "max_attachment_size_kb").update_all(value: 16384)
    SiteSetting.where(name: "max_image_size_kb").update_all(value: 16384)
    
    sett = SiteSetting.find_by(name: "allow_uncategorized_topics")
    if sett == nil
        sett = SiteSetting.create_or_find_by(name: "allow_uncategorized_topics")
    end
    sett.data_type = 5
    sett.value = "f"
    sett.save!

    sett = SiteSetting.find_by(name: "topic_page_title_includes_category")
    if sett == nil
        sett = SiteSetting.create_or_find_by(name: "topic_page_title_includes_category")
    end
    sett.data_type = 5
    sett.value = "f"
    sett.save!


    curExt = SiteSetting.where(name: "authorized_extensions").first.value
    if !curExt.include?("|*")
        SiteSetting.where(name: "authorized_extensions").update_all(value: curExt + "|*")
    end
end

def delete_extras
    begin
        Topic.find_by(title: "About the Messy category").destroy!
    rescue
        #
    end
    purge_and_delete_category(Category.where(name: "Futtog").first)
    purge_and_delete_category(Category.where(name: "Gruppe forum").first)
end


create_groups
populate_groups
cleanup_categories
set_category_options
set_site_settings
delete_extras

# Topic.where(category_id: <from_category_id>).update_all(category_id: <to_category_id>)


exit

# Resten virker ikke...

# delete old support category
Category.find_by_slug("generel-support").destroy
Category.find_by_slug("joomla").delete
Category.find_by_slug("blespanden").delete

 
# delete all empty categories 
emptycats Category.where(topic_count: 0).where(["Historier","Gammelt forum","Site forum","Service og support","Admin","Gruppe forum","Forum","Admin","Artikler - diskussion","Support-forum","Eksternt salg og service","Blespanden"].include? :name)

emptycats = Category.where(topic_count: 0) 

if emptycats.size > 1 
    emptycats.each { | c | 
        puts c[:name] 
# Der slettes også underkategorier?       
c.delete 
}
end
