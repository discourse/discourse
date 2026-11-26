# frozen_string_literal: true

# Executed only inside the disposable container created by review-fixture.
require_relative "/var/www/discourse/script/bulk_import/discourse_merger/merger"

module MemberReviewFixture
  extend self

  def member(name, email)
    User.create!(username: name, email: email, password: SecureRandom.hex(20), active: true)
  end

  def destination
    SiteSetting.external_system_avatars_url = ""
    user = member("FinalName", "first@example.test")
    UserEmail.create!(user: user, email: "second@example.test", primary: false)
    member("Unrelated", "destination@example.test").user_stat.update!(time_read: 123)
    member("Unrelated_1", "occupied@example.test")
    member("KeptName", "same@example.test").user_stat.destroy!
    user.user_stat.update!(posts_read_count: 17)
    UserVisit.create!(user: user, visited_at: "2020-01-01", time_read: 20, posts_read: 3)
    UserVisit.create!(user: user, visited_at: "2019-12-31", time_read: 6)
    photo =
      File.open(Rails.public_path.join("images/default-apple-touch-icon.png")) do |file|
        UploadCreator.new(file, "fixture.png", for_avatar: true).create_for(user.id)
      end
    raise photo.errors.full_messages.join(", ") unless photo.persisted?
    user.update_column(:uploaded_avatar_id, photo.id)
  end

  def source
    SiteSetting.allow_uncategorized_topics = true
    author = member("Before", "first@example.test")
    second = member("Second", "second@example.test")
    created = member("Unrelated", "source@example.test")
    member("KeptName", "same@example.test")
    UserVisit.create!(
      user: author,
      visited_at: "2020-01-01",
      time_read: 30,
      posts_read: 4,
      mobile: true,
    )
    UserVisit.create!(user: second, visited_at: "2020-01-01", time_read: 10, posts_read: 2)
    UserVisit.create!(user: second, visited_at: "2020-01-02", time_read: 7, posts_read: 1)
    UserVisit.create!(user: created, visited_at: "2020-01-03", time_read: 14)
    topic =
      Topic.create!(
        title: "Member review fixture",
        category_id: SiteSetting.uncategorized_category_id,
        user_id: author.id,
        last_post_user_id: author.id,
        bumped_at: Time.current,
      )
    TopicViewItem.insert_all!([{ user_id: author.id, topic_id: topic.id, viewed_at: "2020-01-01" }])
    PostTiming.create!(user_id: author.id, topic_id: topic.id, post_number: 1, msecs: 500)
    image = "/letter_avatar_proxy/v4/letter/b/123456/50.png"
    raw =
      "|User|Hours|\n|---|---|\n|![avatar\\|25x25](#{image}) @Before|4|\n|![avatar\\|25x25](#{image}) @Unrelated|3|"
    Post.insert_all!(
      [
        {
          topic_id: topic.id,
          user_id: author.id,
          post_number: 1,
          raw: raw,
          cooked: PrettyText.cook(raw),
          last_version_at: Time.current,
        },
      ],
    )
  end

  def verify
    member = User.find_by!(username: "FinalName")
    summary = UserSummary.new(member, Guardian.new(member))
    unless [
             summary.days_visited,
             summary.time_read,
             summary.topics_entered,
             summary.posts_read_count,
           ] == [3, 73, 1, 17]
      raise "Summary differs"
    end
    shared = UserVisit.find_by!(user_id: member.id, visited_at: "2020-01-01")
    unless [shared.time_read, shared.posts_read, shared.mobile] == [60, 9, true]
      raise "Overlapping visits differ"
    end
    unless User.find_by!(username: "Unrelated").user_stat.time_read == 123
      raise "Unrelated member changed"
    end

    unless UserVisit.exists?(user_id: User.find_by!(username: "Unrelated_2").id, time_read: 14)
      raise "New member visit missing"
    end
    post = Post.find_by!(user_id: member.id, post_number: 1)
    expected =
      "https://merge.example.test/user_avatar/merge.example.test/finalname/50/#{member.uploaded_avatar_id}_#{OptimizedImage::VERSION}.png"
    if [expected, "@FinalName", "@Unrelated_2"].any? { |value| post.raw.exclude?(value) }
      raise "Saved avatar markup or mentions differ"
    end
    letter =
      "https://merge.example.test#{User.default_template("Unrelated_2").gsub("{size}", "50")}"
    [post.cooked, post.cook(post.raw, topic_id: post.topic_id)].each do |html|
      images = Nokogiri::HTML5.fragment(html).css("img[alt=avatar]")
      unless images.map { |image| image["src"] } == [expected, letter] &&
               images.all? { |image| image["width"] == "25" }
        raise "Rendered avatars differ: #{html}"
      end
    end
    File.write(
      "/tmp/fixture-image-paths",
      [expected, letter].map { |url| URI(url).request_uri }.join("\n") + "\n",
    )
  end
end

unless ENV["MERGE_FIXTURE"] == "1" && Discourse.current_hostname == "merge.example.test"
  raise "Expected an isolated fixture"
end
stage = ENV.fetch("FIXTURE_STAGE")
database = {
  "source" => "fixture_source",
  "destination" => "discourse",
  "verify" => "fixture_restored",
}.fetch(stage)
unless User.connection.select_value("SELECT current_database()") == database
  raise "Unexpected fixture database"
end
MemberReviewFixture.public_send(stage)
