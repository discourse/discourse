# frozen_string_literal: true

require 'discourse_dev/record'
require 'faker'

module DiscourseDev
  class User < Record
    attr_reader :images

    def initialize
      super(::User, DiscourseDev.config.user[:count])

      @images = DiscourseDevAssets.avatars
    end

    def data
      name = Faker::Name.unique.name
      email = Faker::Internet.unique.email(name: name, domain: "faker.invalid")
      username = Faker::Internet.unique.username(specifier: ::User.username_length)
      username = UserNameSuggester.suggest(username)
      username_lower = ::User.normalize_username(username)

      {
        name: name,
        email: email,
        username: username,
        username_lower: username_lower,
        moderator: Faker::Boolean.boolean(true_ratio: 0.1),
        trust_level: Faker::Number.between(from: 1, to: 4),
        created_at: Faker::Time.between(from: DiscourseDev.config.start_date, to: DateTime.now),
      }
    end

    def create!
      super do |user|
        user.activate
        set_random_avatar(user)
        Faker::Number.between(from: 0, to: 2).times do
          group = Group.random

          group.add(user)
        end
      end
    end

    def self.random
      super(::User)
    end

    def set_random_avatar(user)
      return if images.blank?
      return unless Faker::Boolean.boolean

      avatar_index = Faker::Number.between(from: 0, to: images.count - 1)
      avatar_path = images[avatar_index]
      create_avatar(user, avatar_path)
      @images.delete_at(avatar_index)
    end

    def create_avatar(user, avatar_path)
      tempfile = copy_to_tempfile(avatar_path)
      filename = "avatar#{File.extname(avatar_path)}"
      upload = UploadCreator.new(tempfile, filename, type: "avatar").create_for(user.id)

      if upload.present? && upload.persisted?
        user.create_user_avatar
        user.user_avatar.update(custom_upload_id: upload.id)
        user.update(uploaded_avatar_id: upload.id)
      else
        STDERR.puts "Failed to upload avatar for user #{user.username}: #{avatar_path}"
        STDERR.puts upload.errors.inspect if upload
      end
    rescue
      STDERR.puts "Failed to create avatar for user #{user.username}: #{avatar_path}"
    ensure
      tempfile.close! if tempfile
    end

    private

    def copy_to_tempfile(source_path)
      extension = File.extname(source_path)
      tmp = Tempfile.new(['discourse-upload', extension])

      File.open(source_path) do |source_stream|
        IO.copy_stream(source_stream, tmp)
      end

      tmp.rewind
      tmp
    end
  end
end
