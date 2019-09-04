# frozen_string_literal: true

require_dependency 'ip_addr'

# Responsible for destroying a User record
class UserDestroyer

  class PostsExistError < RuntimeError; end

  def initialize(actor)
    @actor = actor
    raise Discourse::InvalidParameters.new('acting user is nil') unless @actor && @actor.is_a?(User)
    @guardian = Guardian.new(actor)
  end

  # Returns false if the user failed to be deleted.
  # Returns a frozen instance of the User if the delete succeeded.
  def destroy(user, opts = {})
    raise Discourse::InvalidParameters.new('user is nil') unless user && user.is_a?(User)
    raise PostsExistError if !opts[:delete_posts] && user.posts.count != 0
    @guardian.ensure_can_delete_user!(user)

    # default to using a transaction
    opts[:transaction] = true if opts[:transaction] != false

    prepare_for_destroy(user) if opts[:prepare_for_destroy] == true

    result = nil

    optional_transaction(open_transaction: opts[:transaction]) do

      Draft.where(user_id: user.id).delete_all
      Reviewable.where(created_by_id: user.id).delete_all

      if opts[:delete_posts]
        user.posts.each do |post|

          # agree with flags
          if opts[:delete_as_spammer] && reviewable = post.reviewable_flag
            reviewable.perform(@actor, :agree_and_keep)
          end

          # block all external urls
          if opts[:block_urls]
            post.topic_links.each do |link|
              next if link.internal
              next if Oneboxer.engine(link.url) != Onebox::Engine::WhitelistedGenericOnebox
              ScreenedUrl.watch(link.url, link.domain, ip_address: user.ip_address)&.record_match!
            end
          end

          PostDestroyer.new(@actor.staff? ? @actor : Discourse.system_user, post).destroy

          if post.topic && post.is_first_post?
            Topic.unscoped.where(id: post.topic_id).update_all(user_id: nil)
          end
        end
      end

      user.post_actions.each do |post_action|
        post_action.remove_act!(Discourse.system_user)
      end

      # Add info about the user to staff action logs
      UserHistory.staff_action_records(
        Discourse.system_user, acting_user: user.username
      ).each do |log|
        log.details ||= ''
        log.details = (log.details.split("\n") +
            ["user_id: #{user.id}", "username: #{user.username}"]
          ).join("\n")
        log.save!
      end

      # keep track of emails used
      user_emails = user.user_emails.pluck(:email)

      if result = user.destroy
        if opts[:block_email]
          user_emails.each do |email|
            ScreenedEmail.block(email, ip_address: result.ip_address)&.record_match!
          end
        end

        if opts[:block_ip] && result.ip_address
          ScreenedIpAddress.watch(result.ip_address)&.record_match!
          if result.registration_ip_address && result.ip_address != result.registration_ip_address
            ScreenedIpAddress.watch(result.registration_ip_address)&.record_match!
          end
        end

        Post.unscoped.where(user_id: result.id).update_all(user_id: nil)

        # If this user created categories, fix those up:
        Category.where(user_id: result.id).each do |c|
          c.user_id = Discourse::SYSTEM_USER_ID
          c.save!
          if topic = Topic.unscoped.find_by(id: c.topic_id)
            topic.recover!
            topic.user_id = Discourse::SYSTEM_USER_ID
            topic.save!
          end
        end

        unless opts[:quiet]
          if @actor == user
            deleted_by = Discourse.system_user
            opts[:context] = I18n.t("staff_action_logs.user_delete_self", url: opts[:context])
          else
            deleted_by = @actor
          end
          StaffActionLogger.new(deleted_by).log_user_deletion(user, opts.slice(:context))
        end
        MessageBus.publish "/logout", result.id, user_ids: [result.id]
      end
    end

    # After the user is deleted, remove the reviewable
    if reviewable = ReviewableUser.pending.find_by(target: user)
      reviewable.perform(@actor, :reject_user_delete)
    end

    result
  end

  protected

  def prepare_for_destroy(user)
    PostAction.where(user_id: user.id).delete_all
    UserAction.where('user_id = :user_id OR target_user_id = :user_id OR acting_user_id = :user_id', user_id: user.id).delete_all
    PostTiming.where(user_id: user.id).delete_all
    TopicViewItem.where(user_id: user.id).delete_all
    TopicUser.where(user_id: user.id).delete_all
    TopicAllowedUser.where(user_id: user.id).delete_all
    Notification.where(user_id: user.id).delete_all
  end

  def optional_transaction(open_transaction: true)
    if open_transaction
      User.transaction { yield  }
    else
      yield
    end
  end

end
