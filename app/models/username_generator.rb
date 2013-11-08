module UsernameGenerator

  extend self

  def generate(email)
    root = email.match(/\A(\w+?)\W/)[1] rescue ''
    nums = 5.times.map{ |n| random_number }
    names = [root] + nums.map{ |n| "#{root}#{n}" } + nums.map{ |n| "User#{n}" }
    names.find{ |name| valid_username?(name) }
  end

  private

  # Discourse's UsernameValidator just validates format, let's keep it that way - the less merges, the better ;)
  def valid_username?(name)
    UsernameValidator.new(name).valid_format? &&
        (User.where(username: name).count == 0) &&
        (LpUserInfo.where(screen_name: name).count == 0)
  end

  def random_number
    @@random_numbers ||= (100..999).to_a
    pick_random @@random_numbers
  end

  def pick_random(arr)
    arr[ SecureRandom.random_number(arr.size) ]
  end

end
