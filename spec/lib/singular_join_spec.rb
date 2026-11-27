# frozen_string_literal: true

RSpec.describe SingularJoin do
  fab!(:user)

  it "loads nested belongs_to and has_one associations with inverses in one query" do
    query =
      described_class.compile(UserAuthToken, with: { user: %i[user_option user_stat] }) do
        where("id = :id")
      end
    token = UserAuthToken.generate!(user_id: user.id)

    queries =
      track_sql_queries do
        found = query.first(id: token.id)
        expect(found).to eq(token)
        expect(found.acting_user).to eq(user)
        expect(found.acting_user.user_option.user_id).to eq(user.id)
        expect(found.acting_user.user_option.user).to equal(found.acting_user)
        expect(found.acting_user.user_stat.user_id).to eq(user.id)
        expect(found.acting_user.user_stat.user).to equal(found.acting_user)
      end

    expect(queries.size).to eq(1)
  end

  it "hydrates typed attributes and tracks in-place changes like Active Record" do
    freeze_time Time.current.change(usec: 0)
    member = Fabricate(:user, ip_address: "2001:db8::1234", date_of_birth: Date.new(1990, 2, 3))
    member.user_option.update!(
      theme_ids: [1, 2],
      understood_languages: %w[en fr],
      default_calendar: :google,
      push_notification_level: :chat_only,
    )
    token = UserAuthToken.generate!(user_id: member.id, client_ip: "192.0.2.1")
    query =
      described_class.compile(UserAuthToken, with: { user: :user_option }) { where("id = :id") }

    found = query.first(id: token.id)
    loaded_options = found.acting_user.user_option
    expected_options = UserOption.find(member.id)

    [
      [found, UserAuthToken.find(token.id)],
      [found.acting_user, User.find(member.id)],
      [loaded_options, expected_options],
    ].each do |record, expected|
      expect(record.attributes).to eq(expected.attributes)
      expect(record.attributes.transform_values(&:class)).to eq(
        expected.attributes.transform_values(&:class),
      )
      expect(record).not_to be_changed
      expect(
        record.attributes.keys.select { |name| record.attribute_changed_in_place?(name) },
      ).to be_empty
    end

    loaded_options.theme_ids << 3
    expected_options.theme_ids << 3
    expect(loaded_options.attribute_changed_in_place?("theme_ids")).to be(true)
    expect(loaded_options.changes).to eq(expected_options.changes)

    loaded_options.save!
    expect(UserOption.find(member.id).theme_ids).to eq([1, 2, 3])
  end

  it "marks missing associations as loaded nil without follow-up queries" do
    query =
      described_class.compile(UserAuthToken, with: { user: :user_option }) { where("id = :id") }

    token = UserAuthToken.generate!(user_id: user.id)
    UserOption.where(user_id: user.id).delete_all
    found = query.first(id: token.id)
    expect(
      track_sql_queries do
        expect(found.acting_user).to eq(user)
        expect(found.acting_user.association(:user_option)).to be_loaded
        expect(found.acting_user.user_option).to be_nil
      end,
    ).to be_empty

    User.where(id: user.id).delete_all
    found = query.first(id: token.id)
    expect(found.association(:user)).to be_loaded
    expect(track_sql_queries { expect(found.acting_user).to be_nil }).to be_empty
  end

  it "rebuilds the cached SQL plan when a participating model reloads its columns" do
    ignored_columns = UserOption.ignored_columns
    query =
      described_class.compile(UserAuthToken, with: { user: :user_option }) { where("id = :id") }
    token = UserAuthToken.generate!(user_id: user.id)
    query.first(id: token.id)

    UserOption.ignored_columns += ["timezone"]
    UserOption.reset_column_information

    queries =
      track_sql_queries do
        options = query.first(id: token.id).acting_user.user_option
        expect(options).not_to have_attribute(:timezone)
      end
    expect(queries.size).to eq(1)
  ensure
    UserOption.ignored_columns = ignored_columns
    UserOption.reset_column_information
  end

  it "appends sanitized SQL comments" do
    user_id = user.id
    query = described_class.compile(User, with: :user_option) { where("id = :id") }

    queries =
      track_sql_queries do
        found = query.first(id: user_id, comment: "path:/latest */ /*\nfoo")
        expect(found).to eq(user)
      end

    expect(queries.size).to eq(1)
    expect(queries.first).to include("/* path:/latest * / / * foo */")
  end

  it "rejects unsupported associations" do
    [
      [User, :does_not_exist, /Unknown association/],
      [User, :posts, /only supports belongs_to and has_one/],
      [User, :primary_email, /Scoped association/],
      [User, :master_user, /Through association/],
      [UploadReference, :target, /Polymorphic association/],
      [Topic, :topic_embed, /default_scopes/],
    ].each do |model, assoc, pattern|
      query = described_class.compile(model, with: assoc) { where("1 = 0") }
      expect { query.first }.to raise_error(ArgumentError, pattern)
    end
  end
end
