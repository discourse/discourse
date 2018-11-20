class Admin::WatchedWordsController < Admin::AdminController

  def index
    render_json_dump WatchedWordListSerializer.new(WatchedWord.by_action, scope: guardian, root: false)
  end

  def create
    watched_word = WatchedWord.create_or_update_word(watched_words_params)
    if watched_word.valid?
      render json: watched_word, root: false
    else
      render_json_error(watched_word)
    end
  end

  def destroy
    watched_word = WatchedWord.find(params[:id])
    watched_word.destroy
    render json: success_json
  end

  def upload
    file = params[:file] || params[:files].first
    action_key = params[:action_key].to_sym

    Scheduler::Defer.later("Upload watched words") do
      begin
        File.open(file.tempfile, encoding: "ISO-8859-1").each_line do |line|
          WatchedWord.create_or_update_word(word: line, action_key: action_key) unless line.empty?
        end
        data = { url: '/ok' }
      rescue => e
        data = failed_json.merge(errors: [e.message])
      end
      MessageBus.publish("/uploads/csv", data.as_json, client_ids: [params[:client_id]])
    end

    render json: success_json
  end

  private

  def watched_words_params
    params.permit(:id, :word, :action_key)
  end

end
