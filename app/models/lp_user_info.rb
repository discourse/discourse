class LpUserInfo < ActiveRecord::Base

  belongs_to :user

  # Fetches the user data from the lessonplanet API and finds or creates a UserInfo for it
  def self.find_or_create_from_oauth_token(oauth_token)
    lessonplanet_data = fetch_lessonplanet_data(oauth_token)
    where(lp_user_id: lessonplanet_data[:lessonplanet_uid]).first || create_from_lessonplanet_data(lessonplanet_data[:lessonplanet_uid], lessonplanet_data[:email])
  end

  private

  # Returns email and lessonplanet_uid from the lessonplanet API
  def self.fetch_lessonplanet_data(oauth_token)
    lessonplanet_data = MultiJson.decode(
    Faraday.new(ENV["LESSON_PLANET_AUTH_URL"]).get('/api/v2/account') do |r|
      r.headers['Accept'] = 'application/json'
      r.headers['Authorization'] = "Bearer #{oauth_token}"
    end.body)
    { email: lessonplanet_data['email'], lessonplanet_uid: lessonplanet_data['id'].to_i }
  end

  def self.create_from_lessonplanet_data(lessonplanet_uid, email)
    username = UsernameGenerator.generate(email)
    user_info = new(lp_user_id: lessonplanet_uid, screen_name: username)
    user = User.create!(email: email, username: username, active: true, name: email)
    user_info.user = user
    user_info.save
    user_info
  end

end
