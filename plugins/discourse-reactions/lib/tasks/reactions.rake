# frozen_string_literal: true

def words_list
  @words_list ||= [
    "etsy",
    "twee",
    "hoodie",
    "Banksy",
    "retro",
    "synth",
    "single-origin",
    "coffee",
    "art",
    "party",
    "cliche",
    "artisan",
    "Williamsburg",
    "squid",
    "helvetica",
    "keytar",
    "American Apparel",
    "craft beer",
    "food truck",
    "you probably haven't heard of them",
    "cardigan",
    "aesthetic",
    "raw denim",
    "sartorial",
    "gentrify",
    "lomo",
    "Vice",
    "Pitchfork",
    "Austin",
    "sustainable",
    "salvia",
    "organic",
    "thundercats",
    "PBR",
    "iPhone",
    "lo-fi",
    "skateboard",
    "jean shorts",
    "next level",
    "beard",
    "tattooed",
    "trust fund",
    "Four Loko",
    "master cleanse",
    "ethical",
    "high life",
    "wolf moon",
    "fanny pack",
    "Terry Richardson",
    "8-bit",
    "Carles",
    "Shoreditch",
    "seitan",
    "freegan",
    "keffiyeh",
    "biodiesel",
    "quinoa",
    "farm-to-table",
    "fixie",
    "viral",
    "chambray",
    "scenester",
    "leggings",
    "readymade",
    "Brooklyn",
    "Wayfarers",
    "Marfa",
    "put a bird on it",
    "dreamcatcher",
    "photo booth",
    "tofu",
    "mlkshk",
    "vegan",
    "vinyl",
    "DIY",
    "banh mi",
    "bicycle rights",
    "before they sold out",
    "gluten-free",
    "yr butcher blog",
    "whatever",
    "Cosby Sweater",
    "VHS",
    "messenger bag",
    "cred",
    "locavore",
    "mustache",
    "tumblr",
    "Portland",
    "mixtape",
    "fap",
    "letterpress",
    "McSweeney's",
    "stumptown",
    "brunch",
    "Wes Anderson",
    "irony",
    "echo park",
  ]
end

def generate_email
  email = words_list.sample.delete(" ") + "@" + words_list.sample.delete(" ") + ".com"
  email.delete("'").force_encoding("UTF-8")
end

def create_user(user_email)
  user = User.find_by_email(user_email)
  unless user
    puts "Creating new account: #{user_email}"
    user =
      User.create!(
        email: user_email,
        password: SecureRandom.hex,
        username: UserNameSuggester.suggest(user_email),
      )
  end
  user.active = true
  user.save!
  user
end

desc "create users and generate random reactions on a post"
task "reactions:generate", %i[post_id reactions_count reaction] => [:environment] do |_, args|
  if !Rails.env.development?
    raise "rake reactions:generate should only be run in RAILS_ENV=development, as you are creating fake reactions to posts"
  end

  post_id = args[:post_id]

  return if !post_id

  post = Post.find_by(id: post_id)

  return if !post

  reactions_count = args[:reactions_count] ? args[:reactions_count].to_i : 10

  reactions_count.times do
    reaction = args[:reaction] || DiscourseReactions::Reaction.valid_reactions.to_a.sample
    user = create_user(generate_email)

    puts "Reaction to post #{post.id} with reaction: #{reaction}"
    DiscourseReactions::ReactionManager.new(
      reaction_value: reaction,
      user: user,
      post: post,
    ).toggle!
  end
end
