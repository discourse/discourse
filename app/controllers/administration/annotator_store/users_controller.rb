class Administration::AnnotatorStore::UsersController < Administration::ApplicationController


  # URL: /administration/annotator/users.json
  def index
    users = User.where(active: true).joins("LEFT JOIN user_custom_fields ON user_custom_fields.user_id = users.id AND user_custom_fields.name = 'edgeryders_consent'").select('users.id, users.username, user_custom_fields.value as edgeryders_consent').order('users.id ASC')

    user_data = users.map {|u| {id: u.id, username: u.username, edgeryders_consent: u.edgeryders_consent} }

    respond_to do |format|
      format.json { render json: JSON.pretty_generate(user_data) }
    end
  end


end
