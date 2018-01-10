class Administration::AnnotatorStore::UsersController < Administration::ApplicationController


  # URL: /administration/annotator/users.json
  def index
    users = User.where(active: true).joins("LEFT JOIN user_custom_fields ON user_custom_fields.user_id = users.id AND user_custom_fields.name = 'consent_opencare'").select('users.id, users.username, user_custom_fields.value as consent_opencare').order('users.id ASC')

    user_data = users.map {|u| {id: u.id, username: u.username, consent_opencare: u.consent_opencare} }

    respond_to do |format|
      format.json { render json: JSON.pretty_generate(user_data) }
    end
  end


end
