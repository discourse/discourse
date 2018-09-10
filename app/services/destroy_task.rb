## Because these methods are meant to be called from a rake task
#   we are capturing all log output into a log array to return
#   to the rake task rather than using `puts` statements.
class DestroyTask
  def self.destroy_topics(category, parent_category = nil)
    c = Category.find_by_slug(category, parent_category)
    log = []
    descriptive_slug = parent_category ? "#{parent_category}/#{category}" : category
    return "A category with the slug: #{descriptive_slug} could not be found" if c.nil?
    topics = Topic.where(category_id: c.id, pinned_at: nil).where.not(user_id: -1)
    log << "There are #{topics.count} topics to delete in #{descriptive_slug} category"
    topics.each do |topic|
      log << "Deleting #{topic.slug}..."
      first_post = topic.ordered_posts.first
      if first_post.nil?
        return log << "Topic.ordered_posts.first was nil"
      end
      system_user = User.find(-1)
      log << PostDestroyer.new(system_user, first_post).destroy
    end
    log
  end

  def self.destroy_topics_all_categories
    categories = Category.all
    log = []
    categories.each do |c|
      log << destroy_topics(c.slug, c.parent_category&.slug)
    end
    log
  end

  def self.destroy_private_messages
    pms = Topic.where(archetype: "private_message")
    current_user = User.find(-1) #system
    log = []
    pms.each do |pm|
      log << "Destroying #{pm.slug} pm"
      first_post = pm.ordered_posts.first
      log << PostDestroyer.new(current_user, first_post).destroy
    end
    log
  end

  def self.destroy_groups
    groups = Group.where(automatic: false)
    log = []
    groups.each do |group|
      log << "destroying group: #{group.id}"
      log << group.destroy
    end
    log
  end

  def self.destroy_users
    log = []
    users = User.where(admin: false, id: 1..Float::INFINITY)
    log << "There are #{users.count} users to delete"
    options = {}
    options[:delete_posts] = true
    current_user = User.find(-1) #system
    users.each do |user|
      begin
        if UserDestroyer.new(current_user).destroy(user, options)
          log << "#{user.username} deleted"
        else
          log << "#{user.username} not deleted"
        end
      rescue UserDestroyer::PostsExistError
        raise Discourse::InvalidAccess.new("User #{user.username} has #{user.post_count} posts, so can't be deleted.")
      rescue NoMethodError
        log << "#{user.username} could not be deleted"
      end
    end
    log
  end

  def self.destroy_stats
    ApplicationRequest.destroy_all
    IncomingLink.destroy_all
    UserVisit.destroy_all
    UserProfileView.destroy_all
    user_profiles = UserProfile.all
    user_profiles.each do |user_profile|
      user_profile.views = 0
      user_profile.save!
    end
    PostAction.unscoped.destroy_all
    EmailLog.destroy_all
  end
end
