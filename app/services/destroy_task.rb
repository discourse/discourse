# frozen_string_literal: true

class DestroyTask
  def initialize(io = STDOUT)
    @io = io
  end

  def destroy_topics(category, parent_category = nil, delete_system_topics = false)
    c = Category.find_by_slug(category, parent_category)
    descriptive_slug = parent_category ? "#{parent_category}/#{category}" : category
    return @io.puts "A category with the slug: #{descriptive_slug} could not be found" if c.nil?
    if delete_system_topics
      topics = Topic.where(category_id: c.id, pinned_at: nil)
    else
      topics = Topic.where(category_id: c.id, pinned_at: nil).where.not(user_id: -1)
    end
    @io.puts "There are #{topics.count} topics to delete in #{descriptive_slug} category"
    topics.find_each do |topic|
      @io.puts "Deleting #{topic.slug}..."
      first_post = topic.ordered_posts.first
      if first_post.nil?
        return @io.puts "Topic.ordered_posts.first was nil"
      end
      @io.puts PostDestroyer.new(Discourse.system_user, first_post).destroy
    end
  end

  def destroy_topics_in_category(category_id, delete_system_topics = false)
    c = Category.find(category_id)
    return @io.puts "A category with the id: #{category_id} could not be found" if c.nil?
    if delete_system_topics
      topics = Topic.where(category_id: c.id, pinned_at: nil)
    else
      topics = Topic.where(category_id: c.id, pinned_at: nil).where.not(user_id: -1)
    end
    @io.puts "There are #{topics.count} topics to delete in #{c.slug} category"
    topics.find_each do |topic|
      first_post = topic.ordered_posts.first
      return @io.puts "Topic.ordered_posts.first was nil for topic: #{topic.id}" if first_post.nil?
      PostDestroyer.new(Discourse.system_user, first_post).destroy
    end
    topics = Topic.where(category_id: c.id, pinned_at: nil)
    @io.puts "There are #{topics.count} topics that could not be deleted in #{c.slug} category"
  end

  def destroy_topics_all_categories
    categories = Category.all
    categories.each do |c|
      @io.puts destroy_topics(c.slug, c.parent_category&.slug)
    end
  end

  def destroy_private_messages
    Topic.where(archetype: "private_message").find_each do |pm|
      @io.puts "Destroying #{pm.slug} pm"
      first_post = pm.ordered_posts.first
      @io.puts PostDestroyer.new(Discourse.system_user, first_post).destroy
    end
  end

  def destroy_category(category_id, destroy_system_topics = false)
    c = Category.find_by_id(category_id)
    return @io.puts "A category with the id: #{category_id} could not be found" if c.nil?
    subcategories = Category.where(parent_category_id: c.id)
    @io.puts "There are #{subcategories.count} subcategories to delete" if subcategories
    subcategories.each do |s|
      category_topic_destroyer(s, destroy_system_topics)
    end
    category_topic_destroyer(c, destroy_system_topics)
  end

  def destroy_groups
    groups = Group.where(automatic: false)
    groups.each do |group|
      @io.puts "destroying group: #{group.id}"
      @io.puts group.destroy
    end
  end

  def destroy_users
    User.human_users.where(admin: false).find_each do |user|
      begin
        if UserDestroyer.new(Discourse.system_user).destroy(user, delete_posts: true, context: "destroy task")
          @io.puts "#{user.username} deleted"
        else
          @io.puts "#{user.username} not deleted"
        end
      rescue UserDestroyer::PostsExistError
        raise Discourse::InvalidAccess.new("User #{user.username} has #{user.post_count} posts, so can't be deleted.")
      rescue NoMethodError
        @io.puts "#{user.username} could not be deleted"
      rescue Discourse::InvalidAccess => e
        @io.puts "#{user.username} #{e.message}"
      end
    end
  end

  def destroy_stats
    ApplicationRequest.delete_all
    IncomingLink.delete_all
    UserVisit.delete_all
    UserProfileView.delete_all
    UserProfile.update_all(views: 0)
    PostAction.unscoped.delete_all
    EmailLog.delete_all
  end

  private

  def category_topic_destroyer(category, destroy_system_topics = false)
    destroy_topics_in_category(category.id, destroy_system_topics)
    @io.puts "Destroying #{category.slug} category"
    category.destroy
  end

end
