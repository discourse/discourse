# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260311064518_clean_existing_tag_localization_names.rb")

describe CleanExistingTagLocalizationNames do
  fab!(:tag)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert_localization(locale, name)
    DB.query_single(
      "INSERT INTO tag_localizations (tag_id, locale, name, created_at, updated_at) VALUES (:tag_id, :locale, :name, NOW(), NOW()) RETURNING id",
      tag_id: tag.id,
      locale: locale,
      name: name,
    ).first
  end

  def name_for(id)
    DB.query_single("SELECT name FROM tag_localizations WHERE id = :id", id: id).first
  end

  it "cleans names with special characters" do
    loc = insert_localization("nl", 'mijn-naam" (123)')

    described_class.new.up

    expect(name_for(loc)).to eq("mijn-naam-123")
  end

  it "replaces whitespace with dashes" do
    loc = insert_localization("nl", "finances & accounting")

    described_class.new.up

    expect(name_for(loc)).to eq("finances-accounting")
  end

  it "lowercases when force_lowercase_tags is enabled" do
    SiteSetting.force_lowercase_tags = true
    loc = insert_localization("nl", "MyTag")

    described_class.new.up

    expect(name_for(loc)).to eq("mytag")
  end

  it "truncates names exceeding max_tag_length" do
    SiteSetting.max_tag_length = 10
    loc = insert_localization("nl", "a" * 20)

    described_class.new.up

    expect(name_for(loc).length).to eq(10)
  end

  it "skips clean names" do
    loc = insert_localization("ja", "猫タグ")

    described_class.new.up

    expect(name_for(loc)).to eq("猫タグ")
  end

  it "does not blank out names that clean to empty" do
    loc = insert_localization("nl", "\"'()")

    described_class.new.up

    expect(name_for(loc)).to eq("\"'()")
  end
end
