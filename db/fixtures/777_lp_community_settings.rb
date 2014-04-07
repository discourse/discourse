#
# Configure Discourse Settings with Lesson Planet Community Settings (rake db:seed_fu)
#

# Load the latest settings
SiteSetting.refresh!

#
# SSO
#
SiteSetting.enable_sso                        = true
SiteSetting.sso_url                           = ENV['SSO_URL']
SiteSetting.sso_secret                        = ENV['SSO_SECRET']
SiteSetting.sso_overrides_email               = true
SiteSetting.sso_overrides_username            = true
SiteSetting.sso_overrides_name                = true
SiteSetting.enable_names                      = true

#
# General
#
SiteSetting.enable_local_account_create       = false
SiteSetting.enforce_global_nicknames          = false
SiteSetting.default_external_links_in_new_tab = true
SiteSetting.title                             = 'Lesson Planet Community Forums'
SiteSetting.company_full_name                 = 'Education Planet, Inc., d/b/a Lesson Planet'
SiteSetting.company_short_name                = 'Lesson Planet'
SiteSetting.logo_url                          = '/images/lp-logo.png'
SiteSetting.logo_small_url                    = '/images/lp-logo-small.png'
SiteSetting.favicon_url                       = '/images/lp-favicon.ico'
SiteSetting.site_description                  = 'THIS IS WHERE THE SITE DESCRIPTION APPEARS'

#
# LessonPlanet API
#
user = User.where(username_lower: ENV['API_USERNAME'].downcase).first
if user.blank?
  user = User.seed do |u|
    u.name = 'Lesson Planet'
    u.username = ENV['API_USERNAME']
    u.username_lower = ENV['API_USERNAME'].downcase
    u.email = 'memberservices@lessonplanet.com'
    u.password = SecureRandom.hex
    # TODO localize this, its going to require a series of hacks
    u.bio_raw = 'Not a real person. A global user for system notifications and other system tasks.'
    u.active = true
    u.admin = true
    u.moderator = true
    u.email_direct = false
    u.approved = true
    u.email_private_messages = false
    u.trust_level = TrustLevel.levels[:elder]
  end.first
end

if user
  api_key = ApiKey.where(user_id: user.id).first_or_initialize
  api_key.update(key: ENV['API_KEY'], created_by: user)
end

# Categories
categories = {
    classroom_support: { name: 'Classroom Support', color: 'BF1E2E', id: 100 },
    college_career_readiness: { name: 'College & Career Readiness', color: 'F1592A', id: 102 },
    common_core_standards: { name: 'Common Core & Standards', color: 'F7941D', id: 103 },
    english_language_arts: { name: 'English Language Arts', color: '9EB83B', id: 104 },
    health: { name: 'Health', color: '3AB54A', id: 105 },
    homeschool: { name: 'Homeschool', color: '12A89D', id: 106 },
    languages: { name: 'Languages', color: '25AAE2', id: 107 },
    lifestyle: { name: 'Lifestyle', color: '0E76BD', id: 108 },
    math: { name: 'Math', color: '652D90', id: 109 },
    physical_education: { name: 'Physical Education', color: '92278F', id: 110 },
    programs: { name: 'Programs', color: 'ED207B', id: 111 },
    science: { name: 'Science', color: '25AAE1', id: 112 },
    social_studies: { name: 'Social Studies', color: 'AB9364', id: 113 },
    technology: { name: 'Technology & Engineering', color: 'D2691E', id: 114 },
    visual_performing_arts: { name: 'Visual & Performing Arts', color: '800080', id: 115 }
}
categories.values.each do |category|
  Category.seed(:id) do |c|
    c.id = category[:id]
    c.name = category[:name]
    c.slug = Slug.for(category[:name])
    c.user_id = Discourse.system_user.id
    c.color = category[:color]
    c.text_color = 'ffffff'
  end
end
# Update auto_increment field
Category.exec_sql "SELECT setval('categories_id_seq', (SELECT MAX(id) from categories));"

uuid = '599ef8a5-9dec-4126-bede-ba48158cb86d'
SiteCustomization.seed(:key) do |sc|
  sc.name = 'Lesson Planet'
  sc.enabled = true
  sc.key = uuid
  sc.position = 0
  sc.user_id = Discourse.system_user.id
  sc.stylesheet = File.read(Rails.root.join('db', 'fixtures', 'lp-style.scss'))
  sc.header = File.read(Rails.root.join('db', 'fixtures', 'lp-header.html'))
end
