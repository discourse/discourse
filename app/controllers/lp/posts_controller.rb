class Lp::PostsController < PostsController
  def create
    resp = { errors:[], topic: nil, comment: nil }

    begin
      ActiveRecord::Base.connection.transaction do
        topic_post_params = {
          skip_validations: true,
          auto_track: false,
          title: params[:topic_title],
          raw: params[:topic_body],
          category: params[:category]
        }

        topic_post = Post.find_by_raw(topic_post_params[:raw])

        unless topic_post.present?
          URI.extract(topic_post_params[:raw], %w(http https)).each do |uri|
            Oneboxer.preview uri, invalidate_oneboxes: true
          end

          topic_user = params[:topic_email].present? ? User.find_by_email(params[:topic_email]) : current_user
          topic_post_creator = PostCreator.new(topic_user, topic_post_params)
          topic_post = topic_post_creator.create
          topic_post.update_column :created_at, params[:created_at] if topic_post.persisted? && params[:created_at].present?
          resp[:errors] << topic_post_creator.errors.full_messages if topic_post_creator.errors.present?
        end

        topic_post_serializer = PostSerializer.new(topic_post, scope: guardian, root: false)
        topic_post_serializer.topic_slug = topic_post.topic.slug
        resp[:topic] = topic_post_serializer

        if params[:comment].present?
          comment_user = params[:comment_email].present? ? User.find_by_email(params[:comment_email]) : current_user

          comment_post_params = {
            skip_validations: true,
            auto_track: false,
            raw: params[:comment],
            topic_id: topic_post.topic.id
          }

          comment_post = Post.where(
            raw: comment_post_params[:raw],
            topic: topic_post.topic,
            user: comment_user
          ).first

          unless comment_post.present?
            comment_post_creator = PostCreator.new(comment_user, comment_post_params)
            comment_post = comment_post_creator.create
            resp[:errors] << comment_post_creator.errors.full_messages if comment_post_creator.errors.present?
          end

          comment_post_serializer = PostSerializer.new(comment_post, scope: guardian, root: false)
          resp[:comment] = comment_post_serializer
        end
      end

    rescue Exception => e
      resp[:errors] << { exception: "#{e.class} #{e.message}", backtrace: e.backtrace }
    end

    render json: MultiJson.dump(resp), status: resp[:errors].present? ? 422 : 200
  end
end
