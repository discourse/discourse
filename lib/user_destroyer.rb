# Responsible for destroying a User record
class UserDestroyer

  class PostsExistError < RuntimeError; end

  def initialize(staff)
    @staff = staff
    raise Discourse::InvalidParameters.new('staff user is nil') unless @staff and @staff.is_a?(User)
    raise Discourse::InvalidAccess unless @staff.staff?
  end

  # Returns false if the user failed to be deleted.
  # Returns a frozen instance of the User if the delete succeeded.
  def destroy(user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise PostsExistError if !opts[:delete_posts] && user.post_count != 0
    User.transaction do
      if opts[:delete_posts]
        user.posts.each do |post|
          if opts[:block_urls]
            post.topic_links.each do |link|
              unless link.internal or Oneboxer.oneboxer_exists_for_url?(link.url)
                ScreenedUrl.watch(link.url, link.domain, ip_address: user.ip_address).try(:record_match!)
              end
            end
          end
          PostDestroyer.new(@staff, post).destroy
          if post.topic and post.post_number == 1
            Topic.unscoped.where(id: post.topic.id).update_all(user_id: nil)
          end
        end
        raise PostsExistError if user.reload.post_count != 0
      end
      user.destroy.tap do |u|
        if u
          if opts[:block_email]
            b = ScreenedEmail.block(u.email, ip_address: u.ip_address)
            b.record_match! if b
          end
          if opts[:block_ip]
            b = ScreenedIpAddress.watch(u.ip_address)
            b.record_match! if b
          end
          Post.with_deleted.where(user_id: user.id).update_all("user_id = NULL")

          # If this user created categories, fix those up:
          categories = Category.where(user_id: user.id)
          categories.each do |c|
            c.user_id = Discourse.system_user.id
            c.save!
            if topic = Topic.with_deleted.where(id: c.topic_id).first
              topic.try(:recover!)
              topic.user_id = Discourse.system_user.id
              topic.save!
            end
          end

          StaffActionLogger.new(@staff).log_user_deletion(user, opts.slice(:context))
          DiscourseHub.unregister_nickname(user.username) if SiteSetting.call_discourse_hub?
          MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
        end
      end
    end
  end

end
