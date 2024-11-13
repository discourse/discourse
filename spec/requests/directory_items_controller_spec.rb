# frozen_string_literal: true

RSpec.describe DirectoryItemsController do
  fab!(:user)
  fab!(:evil_trout)
  fab!(:walter_white)
  fab!(:stage_user) { Fabricate(:staged, username: "stage_user") }
  fab!(:group) { Fabricate(:group, users: [evil_trout, stage_user]) }

  it "requires a `period` param" do
    get "/directory_items.json"
    expect(response.status).to eq(400)
  end

  it "requires a proper `period` param" do
    get "/directory_items.json", params: { period: "eviltrout" }
    expect(response).not_to be_successful
  end

  context "with limit parameter" do
    let!(:users) { Array.new(DirectoryItemsController::PAGE_SIZE + 10) { Fabricate(:user) } }

    before { DirectoryItem.refresh! }

    it "limits the number of returned items" do
      get "/directory_items.json", params: { period: "all", limit: 2 }
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["directory_items"].length).to eq(2)
    end

    include_examples "invalid limit params", "/directory_items.json", described_class::PAGE_SIZE
  end

  context "with page parameter" do
    it "only accepts valid page numbers" do
      get "/directory_items.json", params: { period: "all", page: -1 }
      expect(response.status).to eq(400)

      get "/directory_items.json", params: { period: "all", page: 0 }
      expect(response.status).to eq(200)
    end
  end

  context "with exclude_groups parameter" do
    before { DirectoryItem.refresh! }

    it "excludes users from specified groups" do
      get "/directory_items.json", params: { period: "all", exclude_groups: group.name }
      expect(response.status).to eq(200)
      json = response.parsed_body
      usernames = json["directory_items"].map { |item| item["user"]["username"] }

      expect(usernames).not_to include("eviltrout", "stage_user")
    end

    it "handles non-existent group names gracefully" do
      get "/directory_items.json", params: { period: "all", exclude_groups: "non_existent_group" }
      expect(response.status).to eq(200)
      json = response.parsed_body

      user_names = json["directory_items"].map { |item| item["user"]["username"] }
      expect(user_names).to include("eviltrout")
    end
  end

  context "with exclude_groups parameter and current user in the top positions" do
    before do
      sign_in(evil_trout)
      DirectoryItem.refresh!
    end

    it "doesn't include current user if they are already in the top positions" do
      get "/directory_items.json", params: { period: "all", exclude_groups: group.name }
      expect(response.status).to eq(200)
      json = response.parsed_body
      usernames = json["directory_items"].map { |item| item["user"]["username"] }

      expect(usernames).not_to include("eviltrout")
    end
  end

  context "without data" do
    context "with a logged in user" do
      before { sign_in(user) }

      it "succeeds" do
        get "/directory_items.json", params: { period: "all" }
        expect(response.status).to eq(200)
      end
    end
  end

  context "with data" do
    before { DirectoryItem.refresh! }

    it "succeeds with a valid value" do
      get "/directory_items.json", params: { period: "all" }
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json).to be_present
      expect(json["directory_items"]).to be_present
      expect(json["meta"]["total_rows_directory_items"]).to be_present
      expect(json["meta"]["load_more_directory_items"]).to be_present
      expect(json["meta"]["last_updated_at"]).to be_present

      expect(json["directory_items"].length).to eq(4)
      expect(json["meta"]["total_rows_directory_items"]).to eq(4)
      expect(json["meta"]["load_more_directory_items"]).to include(".json")
    end

    it "respects more_params in load_more_directory_items" do
      get "/directory_items.json",
          params: {
            period: "all",
            order: "likes_given",
            group: group.name,
            user_field_ids: "1|2",
          }
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["meta"]["load_more_directory_items"]).to include("group=#{group.name}")
      expect(json["meta"]["load_more_directory_items"]).to include(
        "user_field_ids=#{CGI.escape("1|2")}",
      )
      expect(json["meta"]["load_more_directory_items"]).to include("order=likes_given")
      expect(json["meta"]["load_more_directory_items"]).to include("period=all")
    end

    it "fails when the directory is disabled" do
      SiteSetting.enable_user_directory = false

      get "/directory_items.json", params: { period: "all" }
      expect(response).not_to be_successful
    end

    it "sort username with asc as a parameter" do
      get "/directory_items.json", params: { asc: true, order: "username", period: "all" }
      expect(response.status).to eq(200)
      json = response.parsed_body

      names = json["directory_items"].map { |item| item["user"]["username"] }
      expect(names).to eq(names.sort)
    end

    it "sort username without asc as a parameter" do
      get "/directory_items.json", params: { order: "username", period: "all" }
      expect(response.status).to eq(200)
      json = response.parsed_body

      names = json["directory_items"].map { |item| item["user"]["username"] }

      expect(names).to eq(names.sort.reverse)
    end

    it "finds user by name" do
      get "/directory_items.json", params: { period: "all", name: "eviltrout" }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json["directory_items"].length).to eq(1)
      expect(json["meta"]["total_rows_directory_items"]).to eq(1)
      expect(json["directory_items"][0]["user"]["username"]).to eq("eviltrout")
    end

    it "finds staged user by name" do
      get "/directory_items.json", params: { period: "all", name: "stage_user" }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json["directory_items"].length).to eq(1)
      expect(json["meta"]["total_rows_directory_items"]).to eq(1)
      expect(json["directory_items"][0]["user"]["username"]).to eq("stage_user")
    end

    it "excludes users by username" do
      get "/directory_items.json",
          params: {
            period: "all",
            exclude_usernames: "stage_user,eviltrout",
          }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json["directory_items"].length).to eq(2)
      expect(json["meta"]["total_rows_directory_items"]).to eq(2)
      expect(json["directory_items"][0]["user"]["username"]).to eq(walter_white.username) |
        eq(user.username)
      expect(json["directory_items"][1]["user"]["username"]).to eq(walter_white.username) |
        eq(user.username)
    end

    it "filters users by group" do
      get "/directory_items.json", params: { period: "all", group: group.name }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to be_present
      expect(json["directory_items"].length).to eq(2)
      expect(json["meta"]["total_rows_directory_items"]).to eq(2)
      expect(json["directory_items"][0]["user"]["username"]).to eq(evil_trout.username) |
        eq(stage_user.username)
      expect(json["directory_items"][1]["user"]["username"]).to eq(evil_trout.username) |
        eq(stage_user.username)
    end

    context "with custom user fields" do
      fab!(:coding_horror)
      # test for sorting by a single user field (single key/value pair)
      # another test that's essentially this: more than one field but only one value each
      # third test for multiselect user field with more than one value each
      # a mix of the two? (one single value, one multiselect)
      it "orders users by a single user field" do
        group.add(walter_white)
        field1 = Fabricate(:user_field, searchable: true)

        user_fields = [
          { user: walter_white, field: field1, value: "Yellow", order: 1 },
          { user: stage_user, field: field1, value: "Apple", order: 0 },
          { user: evil_trout, field: field1, value: "Moon", order: 2 },
          { user: coding_horror, field: field1, value: "ZZZZ", order: 3 },
        ]

        user_fields.each do |data|
          UserCustomField.create!(
            user_id: data[:user].id,
            name: "user_field_#{data[:field].id}",
            value: data[:value],
          )
        end

        get "/directory_items.json",
            params: {
              period: "all",
              group: group.name,
              order: field1.name,
              user_field_ids: "#{field1.id}",
              asc: true,
            }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json).to be_present
        items = json["directory_items"]
        expect(items.length).to eq(3)
        expect(json["meta"]["total_rows_directory_items"]).to eq(3)

        # grab field ids before iterating over values for each field
        field_keys = items.map { |item| item["user"]["user_fields"].keys }.flatten.uniq
        field_values =
          field_keys.map { |key| UserCustomField.find_by(name: "user_field_#{key}").value }
        expect(field_values).to eq(field_values.sort)

        # test order is stage_user, heisenberg, evil_trout, coding_horror
        # received evil_trout first (even after adding in codding_horror, so initial alphabetical assumption isn't correct)
        # expected heisenberg first
        user_fields.each do |data|
          user = items[data[:order]]["user"]
          expect(user["username"]).to eq(data[:user].username)
          expect(user["user_fields"]).to eq(
            { data[:field].id.to_s => { "searchable" => true, "value" => [data[:value]] } },
          )
        end
      end

      it "orders users by multiselect user fields" do
        group.add(walter_white)
        group.add(coding_horror)
        multiselect_field = Fabricate(:multiselect_user_field, searchable: true)

        user_fields = [
          { user: walter_white, field: multiselect_field, value: %w[Yellow 1], order: 1 },
          { user: stage_user, field: multiselect_field, value: %w[Apple 2], order: 0 },
          { user: evil_trout, field: multiselect_field, value: %w[Moon 1], order: 2 },
          { user: coding_horror, field: multiselect_field, value: %w[2 Apartment], order: 3 },
        ]

        user_fields.each do |data|
          UserCustomField.create!(
            user_id: data[:user].id,
            name: "user_field_#{data[:field].id}",
            value: data[:value],
          )
        end

        get "/directory_items.json",
            params: {
              period: "all",
              group: group.name,
              order: multiselect_field.name,
              user_field_ids: "#{multiselect_field.id}",
              asc: true,
            }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json).to be_present
        items = json["directory_items"]
        expect(items.length).to eq(4)
        expect(json["meta"]["total_rows_directory_items"]).to eq(4)

        # user_fields.each do |data|
        #   user = items[data[:order]]["user"]
        #   expect(user["username"]).to eq(data[:user].username)
        #   expect(user["user_fields"]).to eq({ data[:field].id.to_s => data[:value] })
        # end
      end
    end

    it "checks group permissions" do
      group.update!(visibility_level: Group.visibility_levels[:members])

      sign_in(evil_trout)
      get "/directory_items.json", params: { period: "all", group: group.name }
      expect(response.status).to eq(200)

      get "/directory_items.json", params: { period: "all", group: "not a group" }
      expect(response.status).to eq(400)

      sign_in(user)
      get "/directory_items.json", params: { period: "all", group: group.name }
      expect(response.status).to eq(403)
    end

    it "does not force-include self in group-filtered results" do
      me = Fabricate(:user)
      DirectoryItem.refresh!
      sign_in(me)

      get "/directory_items.json", params: { period: "all", group: group.name }
      expect(response.parsed_body["directory_items"].length).to eq(2)
    end
  end
end
