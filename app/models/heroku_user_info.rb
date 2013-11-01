class HerokuUserInfo < ActiveRecord::Base

  belongs_to :user

  # Fetches the user data from the Heroku API and finds or creates a UserInfo for it
  def self.find_or_create_from_oauth_token(oauth_token)
    heroku_data = fetch_heroku_data(oauth_token)
    where(heroku_user_id: heroku_data[:heroku_uid]).first || create_from_heroku_data(heroku_data[:heroku_uid], heroku_data[:email])
  end

  private

  # Returns email and heroku_uid from the Heroku API
  def self.fetch_heroku_data(oauth_token)
    heroku_data = MultiJson.decode(
    Faraday.new(ENV["HEROKU_API_URL"] || "https://api.heroku.com/").get('/account') do |r|
      r.headers['Accept'] = 'application/json'
      r.headers['Authorization'] = "Bearer #{oauth_token}"
    end.body)
    { email: heroku_data['email'], heroku_uid: heroku_data['id'].to_i }
  end

  def self.create_from_heroku_data(heroku_uid, email)
    username = UsernameGenerator.generate(email)
    user_info = new(heroku_user_id: heroku_uid, screen_name: username)
    user = User.create!(email: email, username: username, active: true, name: username)
    user_info.user = user
    user_info.save
    user_info
  end

end