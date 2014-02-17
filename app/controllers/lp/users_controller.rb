class Lp::UsersController < UsersController
  def create
    resp = { errors: [], user: nil }

    begin
      ActiveRecord::Base.connection.transaction do
        user = params[:user]

        user_info = LpUserInfo.where(lp_user_id: user[:id]).first_or_initialize do |u|
          u.screen_name = UsernameGenerator.generate(user[:email])
        end

        new_user = User.where(email: user[:email]).first_or_initialize
        new_user.update_attributes! username: user_info.screen_name, active: true, name: "#{user[:firstname]} #{user[:lastname]}".strip, created_at: user[:created_at], updated_at: user[:updated_at], bio_raw: params[:user_bio] || ''
        user_info.user = new_user
        user_info.save!

        resp[:user] = { id: new_user.id, old_id: user_info[:lp_user_id], username: new_user.username }
      end
    rescue Exception => e
      resp[:errors] = { exception: "#{e.class} #{e.message}", backtrace: e.backtrace }
    end

    render json: MultiJson.dump(resp), status: resp[:errors].present? ? 422 : 200
  end
end
