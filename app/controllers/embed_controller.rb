class EmbedController < ApplicationController
  skip_before_filter :check_xhr
  skip_before_filter :preload_json
  before_filter :ensure_embeddable

  layout 'embed'

  def best
    embed_url = params.require(:embed_url)
    topic_id = TopicEmbed.topic_id_for_embed(embed_url)

    if topic_id
      @topic_view = TopicView.new(topic_id, current_user, {best: 5})
    else
      Jobs.enqueue(:retrieve_topic, user_id: current_user.try(:id), embed_url: embed_url)
      render 'loading'
    end

    discourse_expires_in 1.minute
  end

  private

    def ensure_embeddable
      raise Discourse::InvalidAccess.new('embeddable host not set') if SiteSetting.embeddable_host.blank?
      raise Discourse::InvalidAccess.new('invalid referer host') if URI(request.referer || '').host != SiteSetting.embeddable_host

      response.headers['X-Frame-Options'] = "ALLOWALL"
    rescue URI::InvalidURIError
      raise Discourse::InvalidAccess.new('invalid referer host')
    end


end
