# frozen_string_literal: true

RSpec.describe Boards::Api::CardsController do
  fab!(:admin)
  fab!(:writer, :user)
  fab!(:reader, :user)
  fab!(:outsider, :user)
  fab!(:write_group, :group)
  fab!(:read_group, :group)
  fab!(:category) { Fabricate(:category, name: "Todo") }
  fab!(:topic) { Fabricate(:topic, category: category, user: writer) }
  fab!(:urgent_tag, :tag) { Fabricate(:tag, name: "urgent") }

  fab!(:board) do
    board = Boards::Board.create!(name: "Test Board", slug: "test-board", created_by_id: admin.id)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "edit",
      groups: [write_group],
    )
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "view",
      groups: [read_group],
    )
    board
  end
  fab!(:col_todo) { board.columns.create!(title: "To Do", position: 0) }
  fab!(:done_tag, :tag) { Fabricate(:tag, name: "done") }
  fab!(:col_done) { board.columns.create!(title: "Done", position: 1, tag_id: done_tag.id) }
  fab!(:col_recent) { board.columns.create!(title: "Recent", position: 2, default_sort: "recency") }

  before do
    enable_current_plugin
    write_group.add(writer)
    write_group.add(admin)
    read_group.add(reader)
  end

  describe "POST /boards/api/boards/:board_id/cards" do
    it "creates a floater card" do
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "New task",
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["card_type"]).to eq("floater")
      expect(card["title"]).to eq("New task")
      expect(card["column_id"]).to eq(col_todo.id)
      expect(card["column_changed_at"]).to be_present
      expect(card["recency_at"]).to be_present
    end

    it "enqueues post-processing for a URL-only floater title" do
      url = "https://github.com/discourse/discourse/pull/42462"
      sign_in(writer)

      expect_enqueued_with(job: Jobs::Boards::CardPostProcess, args: { title: url }) do
        post "/boards/api/boards/#{board.id}/cards.json",
             params: {
               card: {
                 column_id: col_todo.id,
                 title: url,
               },
             }
      end

      expect(response.status).to eq(201)
      expect(response.parsed_body.dig("card", "inline_onebox_data")).to be_nil
    end

    it "creates a floater card with tag ids" do
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Tagged task",
               tag_ids: [urgent_tag.id],
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["tag_ids"]).to eq([urgent_tag.id])
      expect(card["tags"].pluck("name")).to eq([urgent_tag.name])
      expect(Boards::Card.find(card["id"]).tag_ids).to eq([urgent_tag.id])
    end

    it "rejects unknown floater card tag ids" do
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Bad tag",
               tag_ids: [urgent_tag.id + 1000],
             },
           }

      expect(response.status).to eq(400)
    end

    it "rejects hidden floater card tag ids" do
      hidden_tag = Fabricate(:tag, name: "staff-urgent")
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Bad tag",
               tag_ids: [hidden_tag.id],
             },
           }

      expect(response.status).to eq(400)
      expect(Boards::Card.where(title: "Bad tag")).to be_empty
    end

    it "creates a topic card" do
      sign_in(writer)

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          post "/boards/api/boards/#{board.id}/cards.json",
               params: {
                 client_id: "test-client",
                 card: {
                   column_id: col_todo.id,
                   topic_id: topic.id,
                 },
               }
        end

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["card_type"]).to eq("topic")
      expect(card["topic_id"]).to eq(topic.id)
      expect(card["topic"]["title"]).to eq(topic.title)

      expect(messages.size).to eq(1)
      expect(messages.first.data).to eq(reload_topic: true, client_id: "test-client")
    end

    it "allows topic cards in different columns when another insert races" do
      inserted_competitor = false
      allow(Boards::CardOrdering).to receive(
        :append_to_column!,
      ).and_wrap_original do |original, card, column|
        unless inserted_competitor
          board.cards.create!(
            card_type: :topic,
            topic_id: topic.id,
            column_id: col_done.id,
            position: 0,
            created_by_id: admin.id,
          )
          inserted_competitor = true
        end

        original.call(card, column)
      end

      sign_in(admin)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: topic.id,
             },
           }

      expect(response.status).to eq(201)
      expect(board.cards.where(topic_id: topic.id).count).to eq(2)

      created_card = board.cards.find_by(topic_id: topic.id, column_id: col_todo.id)
      expect(created_card).to be_present
    end

    it "returns 404 when topic does not exist" do
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: -1,
             },
           }

      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)

      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: private_topic.id,
             },
           }

      expect(response.status).to eq(404)
    end

    it "rejects requests from users without write access" do
      sign_in(reader)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Sneaky card",
             },
           }

      expect(response.status).to eq(403)
    end

    it "rejects anonymous requests" do
      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Anon card",
             },
           }

      expect(response.status).to eq(403)
    end

    it "includes all_assigned_users in the response when assignments exist" do
      skip("requires discourse-assign") unless defined?(Assignment)

      assignee_1 = Fabricate(:user)
      assignee_2 = Fabricate(:user)
      post_in_topic = Fabricate(:post, topic: topic)
      Assignment.create!(
        target: topic,
        topic_id: topic.id,
        assigned_to: assignee_1,
        assigned_by_user: admin,
        active: true,
      )
      Assignment.create!(
        target: post_in_topic,
        topic_id: topic.id,
        assigned_to: assignee_2,
        assigned_by_user: admin,
        active: true,
      )

      sign_in(admin)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: topic.id,
             },
           }

      expect(response.status).to eq(201)
      all_assigned = response.parsed_body.dig("card", "topic", "all_assigned_users")
      expect(all_assigned).to be_present
      usernames = all_assigned.map { |u| u["username"] }
      expect(usernames).to include(assignee_1.username, assignee_2.username)
    end

    it "creates a floater card assigned to a user" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      assignee = Fabricate(:user)
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Assigned task",
               assigned_to_name: assignee.username,
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["assigned_to"]["type"]).to eq("User")
      expect(card["assigned_to"]["username"]).to eq(assignee.username)
    end

    it "creates a floater card assigned to a group" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      group = Fabricate(:group)
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Group task",
               assigned_to_name: group.name,
             },
           }

      expect(response.status).to eq(201)
      card = response.parsed_body["card"]
      expect(card["assigned_to"]["type"]).to eq("Group")
      expect(card["assigned_to"]["name"]).to eq(group.name)
    end

    it "rejects an unknown assignee name" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Bad assignee",
               assigned_to_name: "nonexistent_user_or_group",
             },
           }

      expect(response.status).to eq(400)
    end

    it "rejects assigning a group the user cannot see" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:staff])
      sign_in(writer)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               title: "Hidden group",
               assigned_to_name: hidden_group.name,
             },
           }

      expect(response.status).to eq(400)
    end

    it "applies constraint_fix when creating a topic card" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      ford_tag = Fabricate(:tag, name: "create-ford")
      car_cat = Fabricate(:category, name: "CreateCars")
      board.update!(category_ids: [car_cat.id], tag_ids: [ford_tag.id])
      col_ford = board.columns.create!(title: "CreateFord", position: 2, tag_id: ford_tag.id)

      other_cat = Fabricate(:category, name: "CreateOther")
      mismatched_topic = Fabricate(:topic, category: other_cat, user: admin)
      Fabricate(:post, topic: mismatched_topic, user: admin)

      sign_in(admin)

      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_ford.id,
               topic_id: mismatched_topic.id,
             },
             constraint_fix: {
               category_id: car_cat.id,
               tag_names: %w[create-ford],
             },
           }

      expect(response.status).to eq(201)
      expect(mismatched_topic.reload.category_id).to eq(car_cat.id)
      expect(mismatched_topic.tags.map(&:name)).to include("create-ford")
    end

    it "rejects constraint_fix when creating a card without topic edit access" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      ford_tag = Fabricate(:tag, name: "create-protected-ford")
      car_cat = Fabricate(:category, name: "CreateProtectedCars")
      other_cat = Fabricate(:category, name: "CreateProtectedOther")
      board.update!(category_ids: [car_cat.id], tag_ids: [ford_tag.id])
      col_ford =
        board.columns.create!(title: "CreateProtectedFord", position: 2, tag_id: ford_tag.id)

      protected_topic = Fabricate(:topic, category: other_cat, user: admin)
      Fabricate(:post, topic: protected_topic, user: admin)

      sign_in(writer)

      expect {
        post "/boards/api/boards/#{board.id}/cards.json",
             params: {
               card: {
                 column_id: col_ford.id,
                 topic_id: protected_topic.id,
               },
               constraint_fix: {
                 category_id: car_cat.id,
                 tag_names: [ford_tag.name],
               },
             }
      }.not_to change { Boards::Card.count }

      expect(response.status).to eq(403)
      expect(protected_topic.reload.category_id).to eq(other_cat.id)
      expect(protected_topic.tags).to be_empty
    end

    it "rolls back topic changes when constraint_fix is insufficient and card creation is rejected" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      car_cat = Fabricate(:category, name: "RollbackCars")
      other_cat = Fabricate(:category, name: "RollbackOther")
      rollback_tag = Fabricate(:tag, name: "rollback-tag")
      rb_tag = Fabricate(:tag, name: "rb-create-#{SecureRandom.hex(4)}")
      board.update!(category_ids: [car_cat.id], tag_ids: [rb_tag.id])

      mismatched_topic = Fabricate(:topic, category: other_cat, user: admin)
      Fabricate(:post, topic: mismatched_topic, user: admin)

      sign_in(admin)

      # Fix category but not tags — topic still won't match on an untagged column
      post "/boards/api/boards/#{board.id}/cards.json",
           params: {
             card: {
               column_id: col_todo.id,
               topic_id: mismatched_topic.id,
             },
             constraint_fix: {
               category_id: car_cat.id,
             },
           }

      expect(response.status).to eq(400)
      expect(mismatched_topic.reload.category_id).to eq(other_cat.id)
    end
  end

  describe "PUT /boards/api/boards/:board_id/cards/:id" do
    it "moves a floater card between columns" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Move me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.update_column(:column_changed_at, 2.days.ago)

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_done.id)
      expect(card.column_changed_at).to be > 1.day.ago
      expect(response.parsed_body.dig("card", "column_changed_at")).to be_present
    end

    it "publishes refreshed topic memberships after moving a topic card" do
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
              params: {
                client_id: "test-client",
                card: {
                  column_id: col_done.id,
                },
              }
        end

      expect(response.status).to eq(200)
      membership_message = messages.find { |message| message.data[:reload_topic] }
      expect(membership_message.data).to eq(reload_topic: true, client_id: "test-client")
      expect(membership_message.data).not_to have_key(:board_memberships)
    end

    it "updates a floater card title" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Old title",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              title: "New title",
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.title).to eq("New title")
      expect(response.parsed_body["card"]["title"]).to eq("New title")
    end

    it "clears stale data and enqueues post-processing for a URL-only title update" do
      url = "https://github.com/discourse/discourse/pull/42462"
      card =
        board.cards.create!(
          card_type: :floater,
          title: "https://example.com/old",
          inline_onebox_data: {
            "url" => "https://example.com/old",
            "title" => "Old title",
          },
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      sign_in(writer)

      expect_enqueued_with(
        job: Jobs::Boards::CardPostProcess,
        args: {
          card_id: card.id,
          title: url,
        },
      ) do
        put "/boards/api/boards/#{board.id}/cards/#{card.id}.json", params: { card: { title: url } }
      end

      expect(response.status).to eq(200)
      expect(card.reload.inline_onebox_data).to be_nil
      expect(response.parsed_body.dig("card", "inline_onebox_data")).to be_nil
    end

    it "updates floater card tag ids" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Tag me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              tag_ids: [urgent_tag.id],
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.tag_ids).to eq([urgent_tag.id])
      expect(response.parsed_body.dig("card", "tag_ids")).to eq([urgent_tag.id])
      expect(response.parsed_body.dig("card", "tags").pluck("name")).to eq([urgent_tag.name])
    end

    it "omits restricted tags from update broadcasts" do
      hidden_tag = Fabricate(:tag, name: "secret-boards")
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_category.update!(allowed_tags: [hidden_tag.name])
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Retitle me",
          column_id: col_todo.id,
          position: 0,
          tag_ids: [urgent_tag.id, hidden_tag.id],
          created_by_id: admin.id,
        )

      sign_in(admin)

      messages =
        MessageBus.track_publish("/boards/#{board.id}") do
          put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
              params: {
                card: {
                  title: "Retitled",
                },
              }
        end

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("card", "tags").pluck("name")).to contain_exactly(
        urgent_tag.name,
        hidden_tag.name,
      )
      expect(messages.size).to eq(1)
      expect(messages.first.data[:type]).to eq("card_updated")
      expect(messages.first.data[:card][:tag_ids]).to contain_exactly(urgent_tag.id)
      expect(messages.first.data[:card][:tags].map { |tag| tag[:name] }).to contain_exactly(
        urgent_tag.name,
      )
    end

    it "rejects unknown floater card tag ids on update" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Bad update",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              tag_ids: [urgent_tag.id + 1000],
            },
          }

      expect(response.status).to eq(400)
    end

    it "rejects hidden floater card tag ids on update" do
      hidden_tag = Fabricate(:tag, name: "staff-update")
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Bad update",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              tag_ids: [hidden_tag.id],
            },
          }

      expect(response.status).to eq(400)
      expect(card.reload.tag_ids).to be_empty
    end

    it "preserves notes when omitted from floater updates" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Keep details",
          notes: "Keep this note",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              title: "Updated title only",
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.notes).to eq("Keep this note")
    end

    it "returns 404 when updating a topic card whose topic is hidden from the user" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      private_card =
        board.cards.create!(
          card_type: :topic,
          topic_id: private_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{private_card.id}.json",
          params: {
            card: {
              column_id: col_todo.id,
            },
          }

      expect(response.status).to eq(404)
      expect(response.body).not_to include(private_topic.title)
    end

    it "applies topic mutations when moving a topic card to a new column" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_done.id)
      expect(topic.reload.tags.map(&:name)).to include("done")
    end

    it "reorders within the same column" do
      card1 =
        board.cards.create!(
          card_type: :floater,
          title: "First",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      card2 =
        board.cards.create!(
          card_type: :floater,
          title: "Second",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card1.id}.json",
          params: {
            card: {
              column_id: col_todo.id,
              after_card_id: card2.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card2.reload.position).to be < card1.reload.position
    end

    it "moves cards into column sorted by recency at the top" do
      existing =
        board.cards.create!(
          card_type: :floater,
          title: "Existing",
          column_id: col_recent.id,
          position: 0,
          created_by_id: admin.id,
        )
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Move me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_recent.id,
              after_card_id: existing.id,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_recent.id)
      expect(card.position).to be < existing.reload.position
      expect(response.parsed_body.dig("card", "recency_at")).to be_present
    end

    it "rejects same-column reordering in column sorted by recency" do
      card1 =
        board.cards.create!(
          card_type: :floater,
          title: "First",
          column_id: col_recent.id,
          position: 0,
          created_by_id: admin.id,
        )
      card2 =
        board.cards.create!(
          card_type: :floater,
          title: "Second",
          column_id: col_recent.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card1.id}.json",
          params: {
            card: {
              column_id: col_recent.id,
              after_card_id: card2.id,
            },
          }

      expect(response.status).to eq(400)
      expect(card1.reload.position).to eq(0)
    end

    it "promotes a floater card to a topic card" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          notes: "Some notes",
          tag_ids: [urgent_tag.id],
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      result = response.parsed_body["card"]
      expect(result["card_type"]).to eq("topic")
      expect(result["topic_id"]).to eq(topic.id)
      expect(result["title"]).to be_nil
      expect(result["notes"]).to be_nil
      expect(result["tags"]).to eq([])

      card.reload
      expect(card.topic_id).to eq(topic.id)
      expect(card).to be_topic
      expect(card.title).to be_nil
      expect(card.notes).to be_nil
      expect(card.tag_ids).to eq([])
    end

    it "adopts the existing topic card when promotion races with topic sync insertion" do
      floater =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      inserted_competitor = false
      allow(Boards::TopicMutator).to receive(:apply!).and_wrap_original do |original, **kwargs|
        unless inserted_competitor
          board.cards.create!(
            card_type: :topic,
            topic_id: topic.id,
            column_id: col_todo.id,
            position: 1,
            created_by_id: admin.id,
          )
          inserted_competitor = true
        end

        original.call(**kwargs)
      end

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      expect(board.cards.where(topic_id: topic.id).count).to eq(1)
      expect(Boards::Card.find_by(id: floater.id)).to be_nil
      expect(response.parsed_body.dig("card", "topic_id")).to eq(topic.id)
    end

    it "promotes a floater adopting an existing topic card in the same column" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      result = response.parsed_body["card"]
      expect(result["card_type"]).to eq("topic")
      expect(result["topic_id"]).to eq(topic.id)
      expect(result["column_id"]).to eq(col_todo.id)

      existing_topic_card.reload
      expect(existing_topic_card.column_id).to eq(col_todo.id)

      expect(Boards::Card.find_by(id: floater.id)).to be_nil
    end

    it "includes adopted_floater_id in response when adopting an existing topic card" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{floater.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["adopted_floater_id"]).to eq(floater.id)
      expect(body["card"]["topic_id"]).to eq(topic.id)
    end

    it "publishes card_deleted + card_created events for adoption" do
      existing_topic_card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      floater =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 1,
          created_by_id: admin.id,
        )

      sign_in(admin)

      messages =
        MessageBus.track_publish("/boards/#{board.id}") do
          put "/boards/api/boards/#{board.id}/cards/#{floater.id}.json",
              params: {
                card: {
                  topic_id: topic.id,
                },
              }
        end

      expect(response.status).to eq(200)
      types = messages.map { |m| m.data[:type] }
      expect(types).to contain_exactly("card_deleted", "card_created")
    end

    it "rejects promoting a floater to a topic the user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: private_topic.id,
            },
          }

      expect(response.status).to eq(403)
      expect(card.reload).to be_floater
    end

    it "includes all_assigned_users in the response after a topic card move" do
      skip("requires discourse-assign") unless defined?(Assignment)

      assignee = Fabricate(:user)
      Assignment.create!(
        target: topic,
        topic_id: topic.id,
        assigned_to: assignee,
        assigned_by_user: admin,
        active: true,
      )

      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
          }

      expect(response.status).to eq(200)
      all_assigned = response.parsed_body.dig("card", "topic", "all_assigned_users")
      expect(all_assigned).to be_present
      expect(all_assigned.first["username"]).to eq(assignee.username)
    end

    it "assigns a user to a floater card" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Assign me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      assignee = Fabricate(:user)

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              assigned_to_name: assignee.username,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.assigned_to).to eq(assignee)
      result = response.parsed_body["card"]
      expect(result["assigned_to"]["type"]).to eq("User")
      expect(result["assigned_to"]["username"]).to eq(assignee.username)
    end

    it "assigns a group to a floater card" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Assign group",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      group = Fabricate(:group)

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              assigned_to_name: group.name,
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.assigned_to).to eq(group)
      result = response.parsed_body["card"]
      expect(result["assigned_to"]["type"]).to eq("Group")
      expect(result["assigned_to"]["name"]).to eq(group.name)
    end

    it "unassigns a floater card" do
      assignee = Fabricate(:user)
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Unassign me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              assigned_to_name: "",
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.assigned_to).to be_nil
      expect(response.parsed_body["card"]["assigned_to"]).to be_nil
    end

    it "does not silently clear assignment for unknown assignee name" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      assignee = Fabricate(:user)
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Keep assignee",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              assigned_to_name: "nonexistent_user_or_group",
            },
          }

      expect(response.status).to eq(400)
      expect(card.reload.assigned_to).to eq(assignee)
    end

    it "rejects updating assignment to a group the user cannot see" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      assign_group.add(writer)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Hidden group",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )
      hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:staff])

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              assigned_to_name: hidden_group.name,
            },
          }

      expect(response.status).to eq(400)
      expect(card.reload.assigned_to).to be_nil
    end

    it "clears card-level assignment when promoting a floater to a topic card" do
      skip("requires discourse-assign") unless defined?(::Assigner)
      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s

      assignee = Fabricate(:user)
      assign_group.add(assignee)
      Fabricate(:post, topic: topic)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      card.reload
      expect(card.assigned_to_id).to be_nil
      expect(card.assigned_to_type).to be_nil
    end

    it "carries over card assignment to the topic on promotion" do
      skip("requires discourse-assign") unless defined?(Assignment)

      SiteSetting.assign_enabled = true
      assign_group = Fabricate(:group)
      assignee = Fabricate(:user)
      assign_group.add(assignee)
      SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
      Fabricate(:post, topic: topic)

      card =
        board.cards.create!(
          card_type: :floater,
          title: "Promote me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
          assigned_to: assignee,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              topic_id: topic.id,
            },
          }

      expect(response.status).to eq(200)
      assignment = Assignment.find_by(target: topic, active: true)
      expect(assignment).to be_present
      expect(assignment.assigned_to).to eq(assignee)
    end

    it "rejects requests from users without write access" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Protected",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(reader)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              title: "Hacked",
            },
          }

      expect(response.status).to eq(403)
    end
  end

  describe "PUT /boards/api/boards/:board_id/cards/:id with constraint_fix" do
    fab!(:ford_tag) { Fabricate(:tag, name: "ford") }
    fab!(:chevy_tag) { Fabricate(:tag, name: "chevy") }
    fab!(:car_category) { Fabricate(:category, name: "Cars") }
    fab!(:boat_category) { Fabricate(:category, name: "Boats") }

    it "applies category fix and moves the card" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [car_category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "Ford", position: 2, tag_id: ford_tag.id)

      boat_topic = Fabricate(:topic, category: boat_category, tags: [ford_tag], user: admin)
      Fabricate(:post, topic: boat_topic, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: boat_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              category_id: car_category.id,
            },
          }
      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_ford.id)
      expect(boat_topic.reload.category_id).to eq(car_category.id)
    end

    it "applies tag fix and moves the card" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "Ford", position: 2, tag_id: ford_tag.id)

      car_topic = Fabricate(:topic, category: category, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: car_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              tag_names: %w[ford],
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_ford.id)
      expect(car_topic.reload.tags.map(&:name)).to include("ford")
    end

    it "rejects tag fix without topic edit access" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "ProtectedFord", position: 2, tag_id: ford_tag.id)

      protected_topic = Fabricate(:topic, category: category, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: protected_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              tag_names: [ford_tag.name],
            },
          }

      expect(response.status).to eq(403)
      expect(card.reload.column_id).to eq(col_todo.id)
      expect(protected_topic.reload.tags).to be_empty
    end

    it "applies both category and tag fix" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [car_category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_chevy = board.columns.create!(title: "Chevy", position: 2, tag_id: chevy_tag.id)

      mismatched_topic = Fabricate(:topic, category: boat_category, user: admin)
      Fabricate(:post, topic: mismatched_topic, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: mismatched_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_chevy.id,
            },
            constraint_fix: {
              category_id: car_category.id,
              tag_names: %w[chevy],
            },
          }

      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(col_chevy.id)
      expect(mismatched_topic.reload.category_id).to eq(car_category.id)
      expect(mismatched_topic.tags.map(&:name)).to include("chevy")
    end

    it "rejects constraint_fix with a category not in board constraints" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [car_category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "Ford", position: 2, tag_id: ford_tag.id)

      other_category = Fabricate(:category, name: "Planes")
      boat_topic = Fabricate(:topic, category: boat_category, tags: [ford_tag], user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: boat_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              category_id: other_category.id,
            },
          }

      expect(response.status).to eq(400)
    end

    it "rejects constraint_fix with tags not in board constraints" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [category.id], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "Ford", position: 2, tag_id: ford_tag.id)

      rogue_tag = Fabricate(:tag, name: "rogue")
      car_topic = Fabricate(:topic, category: category, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: car_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              tag_names: [rogue_tag.name],
            },
          }

      expect(response.status).to eq(400)
    end

    it "rejects category fix on a tag-only board" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [], tag_ids: [ford_tag.id, chevy_tag.id])
      col_ford = board.columns.create!(title: "Ford", position: 2, tag_id: ford_tag.id)

      car_topic = Fabricate(:topic, category: category, user: admin)
      Fabricate(:post, topic: car_topic, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: car_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_ford.id,
            },
            constraint_fix: {
              category_id: car_category.id,
            },
          }

      expect(response.status).to eq(400)
    end

    it "rejects tag fix on a category-only board" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      board.update!(category_ids: [car_category.id], tag_ids: [])

      car_topic = Fabricate(:topic, category: boat_category, user: admin)
      Fabricate(:post, topic: car_topic, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: car_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
            constraint_fix: {
              tag_names: %w[ford],
            },
          }

      expect(response.status).to eq(400)
    end

    it "rolls back topic changes when move fails after constraint_fix" do
      SiteSetting.tagging_enabled = true
      allow(Boards::TopicSync).to receive(:sync_topic)

      rb_tag = Fabricate(:tag, name: "rb-update-#{SecureRandom.hex(4)}")
      board.update!(category_ids: [car_category.id], tag_ids: [rb_tag.id])

      # Topic has wrong category and no board tags
      boat_topic = Fabricate(:topic, category: boat_category, user: admin)
      Fabricate(:post, topic: boat_topic, user: admin)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: boat_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(admin)

      # Fix category only — col_done adds done_tag (not in board.tag_ids),
      # and topic has no board tags, so topic_will_match_after_mutation? fails on tags
      put "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
          params: {
            card: {
              column_id: col_done.id,
            },
            constraint_fix: {
              category_id: car_category.id,
            },
          }

      expect(response.status).to eq(400)
      expect(boat_topic.reload.category_id).to eq(boat_category.id)
      expect(card.reload.column_id).to eq(col_todo.id)
    end
  end

  describe "DELETE /boards/api/boards/:board_id/cards/:id" do
    it "destroys a floater card" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Delete me",
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      expect { delete "/boards/api/boards/#{board.id}/cards/#{card.id}.json" }.to change {
        Boards::Card.count
      }.by(-1)

      expect(response.status).to eq(204)
    end

    it "destroys a topic card" do
      board.update!(category_ids: [category.id])

      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          expect do
            delete "/boards/api/boards/#{board.id}/cards/#{card.id}.json",
                   params: {
                     client_id: "test-client",
                   }
          end.to change { Boards::Card.count }.by(-1)
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)
      expect(messages.first.data).to eq(reload_topic: true, client_id: "test-client")
    end

    it "returns 404 when deleting a topic card whose topic is hidden" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      private_card =
        board.cards.create!(
          card_type: :topic,
          topic_id: private_topic.id,
          column_id: col_todo.id,
          position: 0,
          created_by_id: admin.id,
        )

      sign_in(writer)

      expect {
        delete "/boards/api/boards/#{board.id}/cards/#{private_card.id}.json"
      }.not_to change { Boards::Card.count }

      expect(response.status).to eq(404)
      expect(response.body).not_to include(private_topic.title)
    end
  end
end
