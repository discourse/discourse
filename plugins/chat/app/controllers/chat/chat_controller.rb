# frozen_string_literal: true

module Chat
  class ChatController < ::Chat::BaseController
    skip_before_action :check_xhr, if: -> { action_name == "respond" && use_crawler_layout? }
    before_action :set_channel_and_chatable_with_access_check,
                  except: %i[respond set_user_chat_status dismiss_retention_reminder rebake]

    DIRECTORY_PAGE_SIZE = Chat::ChannelFetcher::MAX_PUBLIC_CHANNEL_RESULTS

    def respond
      raise ApplicationController::RenderEmpty if !use_crawler_layout? || current_user

      # Channel routes 404 when anonymous access is off, so already-indexed pages drop out of search.
      if params[:channel_id].present?
        render_crawler_channel
      elsif params[:crawler_directory] && Chat.anonymous_public_channel_access_allowed?
        render_crawler_directory
      else
        raise ApplicationController::RenderEmpty
      end
    end

    def react
      params.require(%i[message_id emoji react_action])
      guardian.ensure_can_react!

      Chat::MessageReactor.new(current_user, @chat_channel).react!(
        message_id: params[:message_id],
        react_action: params[:react_action].to_sym,
        emoji: params[:emoji],
      )

      render json: success_json
    end

    def message_reactions_users
      params.require(:message_id)

      message = Chat::Message.find_by(id: params[:message_id], chat_channel_id: @chat_channel.id)
      raise Discourse::NotFound if message.nil? || !guardian.can_see_chat_message?(message)

      page = params[:page].to_i.clamp(0..)
      limit = params[:limit].present? ? params[:limit].to_i.clamp(1, 50) : 30

      rows, total =
        Chat::MessageReactionUsersQuery.call(
          message: message,
          emoji: params[:emoji],
          limit: limit,
          offset: page * limit,
          current_user_id: current_user.id,
        )

      render_json_dump(users: serialize_data(rows, Chat::ReactionUserSerializer), total_rows: total)
    end

    def rebake
      Chat::RebakeMessage.call(service_params) do
        on_success { render(json: success_json) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:channel) { raise Discourse::NotFound }
        on_failed_policy(:can_access_channel) { raise Discourse::InvalidAccess }
        on_model_not_found(:message) { raise Discourse::NotFound }
        on_failed_policy(:can_rebake) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
      end
    end

    def set_user_chat_status
      params.require(:chat_enabled)

      current_user.user_option.update(chat_enabled: params[:chat_enabled])
      render json: { chat_enabled: current_user.user_option.chat_enabled }
    end

    def dismiss_retention_reminder
      params.require(:chatable_type)
      guardian.ensure_can_chat!
      if Chat::Channel.chatable_types.exclude?(params[:chatable_type])
        raise Discourse::InvalidParameters
      end

      field =
        (
          if Chat::Channel.public_channel_chatable_types.include?(params[:chatable_type])
            :dismissed_channel_retention_reminder
          else
            :dismissed_dm_retention_reminder
          end
        )
      current_user.user_option.update(field => true)
      render json: success_json
    end

    def quote_messages
      params.require(:message_ids)

      message_ids = params[:message_ids].map(&:to_i)
      markdown =
        Chat::TranscriptService.new(
          @chat_channel,
          current_user,
          messages_or_ids: message_ids,
        ).generate_markdown
      render json: success_json.merge(markdown: markdown)
    end

    private

    # Crawler requests skip check_xhr, so respond itself decides what anonymous visitors may see.
    def allow_anonymous_public_chat_access?
      action_name == "respond" && use_crawler_layout?
    end

    def render_crawler_channel
      channel = Chat::Channel.includes(:chatable).find_by_id_or_slug(params[:channel_id])
      raise Discourse::NotFound if !guardian.can_preview_anonymous_public_chat_channel?(channel)

      if params[:thread_id].present?
        thread = channel.threads.find_by(id: params[:thread_id])
        raise Discourse::NotFound if !thread || (!channel.threading_enabled? && !thread.force)
      elsif params[:message_id].present?
        # Channel permalinks to thread replies (e.g. from transcripts) live on the thread page.
        message = channel.chat_messages.find_by(id: params[:message_id])
        return redirect_to(message.url, status: :moved_permanently) if message&.thread_reply?
      end

      @crawler_view =
        Chat::CrawlerView.new(
          channel:,
          thread:,
          date: params[:date],
          page: params[:page],
          target_message_id: params[:message_id],
        )
      raise Discourse::NotFound if !@crawler_view.valid?

      canonical_url(@crawler_view.canonical_url)
      render :crawler_channel
    end

    def render_crawler_directory
      channels =
        Chat::CategoryChannel.joins(
          "INNER JOIN categories ON categories.id = chat_channels.chatable_id",
        ).where(chatable_id: Category.secured(Guardian.new).select(:id))

      page = [params[:page].to_s.to_i, 1].max
      total_pages = [(channels.count.to_f / DIRECTORY_PAGE_SIZE).ceil, 1].max
      raise Discourse::NotFound if page > total_pages

      @crawler_directory_offset = (page - 1) * DIRECTORY_PAGE_SIZE
      @crawler_channels =
        channels
          .includes(:chatable, :last_message)
          .order(
            Arel.sql(
              "LOWER(COALESCE(NULLIF(chat_channels.name, ''), categories.name)), chat_channels.id",
            ),
          )
          .offset(@crawler_directory_offset)
          .limit(DIRECTORY_PAGE_SIZE)

      @crawler_prev_page_url = crawler_directory_url(page - 1) if page > 1
      @crawler_next_page_url = crawler_directory_url(page + 1) if page < total_pages

      canonical_url(crawler_directory_url(page))
      render :crawler_directory
    end

    def crawler_directory_url(page)
      url = "#{Discourse.base_url}/chat"
      page > 1 ? "#{url}?page=#{page}" : url
    end
  end
end
