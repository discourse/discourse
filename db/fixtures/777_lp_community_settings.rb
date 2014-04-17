#
# Configure Discourse Settings with Lesson Planet Community Settings (rake db:seed_fu)
#

#
# Load in the latest settings
#
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
SiteSetting.force_hostname                    = ENV['APP_HOST']
SiteSetting.enable_local_logins               = false
SiteSetting.enforce_global_nicknames          = false
SiteSetting.default_external_links_in_new_tab = true
SiteSetting.title                             = 'Lesson Planet Community Forums'
SiteSetting.company_full_name                 = 'Education Planet, Inc., d/b/a Lesson Planet'
SiteSetting.company_short_name                = 'Lesson Planet'
SiteSetting.contact_email                     = 'MemberServices@lessonplanet.com'
SiteSetting.notification_email                = 'MemberServices@lessonplanet.com'
SiteSetting.logo_url                          = '/images/lp-logo.png'
SiteSetting.logo_small_url                    = '/images/lp-logo-small.png'
SiteSetting.favicon_url                       = '/images/lp-favicon.ico'
SiteSetting.site_description                  = 'Free K-12 teacher discussion forum where educators meet to share ideas about classroom teaching strategies, educational resources, and teacher life.'
SiteSetting.enable_facebook_logins            = false
SiteSetting.enable_twitter_logins             = false
SiteSetting.enable_yahoo_logins               = false
SiteSetting.enable_google_logins              = false
SiteSetting.site_contact_username             = ENV['API_USERNAME']
SiteSetting.company_domain                    = Addressable::URI.parse(ENV['LESSON_PLANET_ROOT_URL']).host
SiteSetting.privacy_policy_url                = "#{ENV['LESSON_PLANET_ROOT_URL'].gsub('https', 'http')}/us/privacy_policy"
SiteSetting.tos_url                           = "#{ENV['LESSON_PLANET_ROOT_URL'].gsub('https', 'http')}/us/terms_of_use"
SiteSetting.ga_universal_tracking_code        = 'UA-214885-13'

# Rate limiting
SiteSetting.unique_posts_mins                 = 5
SiteSetting.rate_limit_create_topic           = 5
SiteSetting.rate_limit_create_post            = 5
SiteSetting.max_topics_per_day                = 20
SiteSetting.title_min_entropy                 = 10
SiteSetting.body_min_entropy                  = 7

#
# Files
#
if ENV['S3_ACCESS_KEY_ID'].present?
  SiteSetting.enable_s3_uploads    = true
  SiteSetting.s3_access_key_id     = ENV['S3_ACCESS_KEY_ID']
  SiteSetting.s3_secret_access_key = ENV['S3_SECRET_ACCESS_KEY']
  SiteSetting.s3_region            = ENV['S3_REGION']
  SiteSetting.s3_upload_bucket     = ENV['S3_UPLOAD_BUCKET']
end

#
# LessonPlanet API
#
User.seed(:username_lower) do |u|
  u.name                   = 'Lesson Planet'
  u.username               = ENV['API_USERNAME']
  u.username_lower         = ENV['API_USERNAME'].downcase
  # LP Site downcases all emails so to find by email this needs to be lowecase.
  u.email                  = 'memberservices@lessonplanet.com'
  u.password               = SecureRandom.hex
  u.bio_raw                = 'Not a real person. A global user for system notifications and other system tasks.'
  u.active                 = true
  u.admin                  = true
  u.moderator              = true
  u.email_direct           = false
  u.approved               = true
  u.email_private_messages = false
  u.trust_level            = TrustLevel.levels[:elder]
end

user = User.find_by_username(ENV['API_USERNAME'])
if user
  api_key = ApiKey.where(user_id: user.id).first_or_initialize
  api_key.update(key: ENV['API_KEY'], created_by: user)
end

# helper method to upload an avatar for a user
def upload_avatar(username, avatar_url)
  user = User.find_by_username_lower(username.downcase)
  if user.present?
    avatar = AvatarUploadService.new(avatar_url, :url)
    upload = Upload.create_for(user.id, avatar.file, avatar.filesize)
    user.upload_avatar(upload)
    Jobs.enqueue(:generate_avatars, user_id: user.id, upload_id: upload.id)
  end
end

# Upload some avatars for our system and API users.
#
# NOTE: Uncomment and run if you need to change the avatar.
# upload_avatar(ENV['API_USERNAME'], 'http://community.lessonplanet.com/images/lp-user-icon.png')
# upload_avatar('system', 'http://community.lessonplanet.com/images/lp-user-icon.png')

#
# Categories
#
Category.find(SiteSetting.uncategorized_category_id).update_attribute :name, 'Miscellaneous'
categories = {
    classroom_support:        { name: 'Classroom Support', color: 'BF1E2E', id: 100 },
    college_career_readiness: { name: 'College & Career Readiness', color: 'F1592A', id: 102 },
    common_core_standards:    { name: 'Common Core & Standards', color: 'F7941D', id: 103 },
    english_language_arts:    { name: 'English Language Arts', color: '9EB83B', id: 104 },
    health:                   { name: 'Health', color: '3AB54A', id: 105 },
    homeschool:               { name: 'Homeschool', color: '12A89D', id: 106 },
    languages:                { name: 'Languages', color: '25AAE2', id: 107 },
    lifestyle:                { name: 'Lifestyle', color: '0E76BD', id: 108 },
    math:                     { name: 'Math', color: '652D90', id: 109 },
    physical_education:       { name: 'Physical Education', color: '92278F', id: 110 },
    programs:                 { name: 'Programs', color: 'ED207B', id: 111 },
    science:                  { name: 'Science', color: '25AAE1', id: 112 },
    social_studies:           { name: 'Social Studies', color: 'AB9364', id: 113 },
    technology:               { name: 'Technology & Engineering', color: 'D2691E', id: 114 },
    visual_performing_arts:   { name: 'Visual & Performing Arts', color: '800080', id: 115 }
}
categories.values.each do |category|
  Category.seed(:id) do |c|
    c.id         = category[:id]
    c.name       = category[:name]
    c.slug       = Slug.for(category[:name])
    c.user_id    = Discourse.system_user.id
    c.color      = category[:color]
    c.text_color = 'ffffff'
  end
end
# Update auto_increment field
Category.exec_sql "SELECT setval('categories_id_seq', (SELECT MAX(id) from categories));"

uuid = '599ef8a5-9dec-4126-bede-ba48158cb86d'
SiteCustomization.seed(:key) do |sc|
  sc.name       = 'Lesson Planet'
  sc.enabled    = true
  sc.key        = uuid
  sc.position   = 0
  sc.user_id    = Discourse.system_user.id
  sc.stylesheet = File.read(Rails.root.join('db', 'fixtures', 'lp-style.scss'))
  sc.header     = File.read(Rails.root.join('db', 'fixtures', 'lp-header.html')).gsub('LESSON_PLANET_ROOT_URL', ENV['LESSON_PLANET_ROOT_URL'].gsub('https', 'http'))
end

sc         = SiteContent.where(content_type: :faq).first_or_initialize
sc.content = File.read(Rails.root.join('db', 'fixtures', 'lp-faq.html'))
sc.save!
