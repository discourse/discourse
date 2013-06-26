# encoding: utf-8
#
desc "Seed database for production"
task "db:seed:welcome" => :environment do
  [User, Category, Topic, Post].each do |klass|
    fail "Database already has some #{klass.name.pluralize}, aborting" if klass.exists?
  end

  include Rails.application.routes.url_helpers

  old_url_options = Rails.application.routes.default_url_options.clone

  host_names = ActiveRecord::Base.connection_pool.spec.config[:host_names]
  host = (host_names || []).first || "localhost"
  if Rails.env == "production" && host =~ /localhost/
    fail "Set the host_names in config/database.yml"
  end
  Rails.application.routes.default_url_options[:host] = host

  port = Rails.env == 'development' ? 3000 : 80
  Rails.application.routes.default_url_options[:port] = port

  ActiveRecord::Base.transaction do
    begin 
      # Not using admin:create cause it will become uneccessary complicated between handling passed args and user input
      admin = User.create!(email: "change_me@example.com", username: "forumadmin", password: "password")
      admin.grant_admin!
      admin.change_trust_level!(TrustLevel.levels.max_by{|k, v| v}.first)
      admin.email_tokens.update_all(confirmed: true) 

      meta_name = I18n.t("welcome.meta.name")
      meta = Category.create!(name: meta_name, user: admin)
      definition = meta.topics.first.posts.first
      definition.raw = I18n.t("welcome.meta.definition")
      definition.save!

      what_is_meta = PostCreator.create(admin, {
        raw: I18n.t("welcome.meta.what_is.raw", faq_url: faq_url),
        reply_to_post_number: "", 
        category: I18n.t("welcome.meta.name"),
        archetype: "regular",
        title: "Long title to pass validation"
      })

      fail "Failed to create post: \n #{p.errors.full_messages.join('\n')}" if what_is_meta.errors.present?

      what_is_meta.topic.update_status("pinned", true, admin)
      what_is_meta.topic.update_attribute(:title, I18n.t("welcome.meta.what_is.title"))

      urls = {admin_url: admin_url,
        tos_url: tos_url,
        meta_url: category_url(category: I18n.t("welcome.meta.name")),
        email_logs_url: logs_admin_email_index_url,
        content_license_url: admin_site_content_url(id: "tos_user_content_license"),
      }

      admin_guide = PostCreator.create(admin, {
        raw: I18n.t("welcome.admin_guide.raw", urls),
        reply_to_post_number: "",
        archetype: "regular",
        title: I18n.t("welcome.admin_guide.title"),
        visible: true
      })

      fail "Failed to create admin guide:\n#{admin_guide.errors.full_messages.join('\n')}" if admin_guide.errors.present?
    ensure
      Rails.application.routes.default_url_options = old_url_options
    end
  end
end



