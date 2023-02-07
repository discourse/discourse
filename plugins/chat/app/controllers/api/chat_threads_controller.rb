# frozen_string_literal: true

class Chat::Api::ChatThreadsController < Chat::Api
  def show
    render json:
             success_json.merge(
               {
                 thread: {
                   id: params[:thread_id],
                   original_message_user: {
                     username: "test",
                   },
                   original_message_excerpt: "this is a cool message",
                 },
               },
             )
  end
end
