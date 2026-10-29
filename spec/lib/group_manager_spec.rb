# frozen_string_literal: true

RSpec.describe GroupManager do
  fab!(:group)
  fab!(:user)
  fab!(:user2, :user)

  subject(:manager) { GroupManager.new(group) }

  describe "#add" do
    it "adds users to group and returns added user IDs" do
      result = manager.add([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id, user2.id)
    end

    it "returns empty array for blank input" do
      expect(manager.add([])).to eq([])
      expect(manager.add(nil)).to eq([])
    end

    it "passes the acting user to each added user's event" do
      admin = Fabricate(:admin)

      events =
        DiscourseEvent.track_events(:user_added_to_group) do
          manager.add([user.id, user2.id], automatic: true, acting_user: admin)
        end

      expect(events).to contain_exactly(
        {
          event_name: :user_added_to_group,
          params: [user, group, { automatic: true, acting_user: admin }],
        },
        {
          event_name: :user_added_to_group,
          params: [user2, group, { automatic: true, acting_user: admin }],
        },
      )
    end

    it "passes a nil acting user when none is given" do
      events = DiscourseEvent.track_events(:user_added_to_group) { manager.add([user.id]) }

      expect(events.first[:params].last).to eq(automatic: false, acting_user: nil)
    end
  end

  describe "user_count" do
    fab!(:bot)

    it "counts bots in automatic groups not created by core" do
      automatic_group = Fabricate(:group, automatic: true)
      automatic_manager = GroupManager.new(automatic_group)

      expect { automatic_manager.add([user.id, bot.id]) }.to change {
        automatic_group.reload.user_count
      }.by(2)
      expect { automatic_manager.remove([bot.id]) }.to change {
        automatic_group.reload.user_count
      }.by(-1)
    end

    it "does not count bots in hand-managed groups" do
      expect { manager.add([user.id, bot.id]) }.to change { group.reload.user_count }.by(1)
      expect { manager.remove([bot.id]) }.not_to change { group.reload.user_count }
    end

    it "does not count bots in core automatic groups" do
      staff_manager = GroupManager.new(Group[:staff])

      expect { staff_manager.add([user.id, bot.id]) }.to change { Group[:staff].user_count }.by(1)
      expect { staff_manager.remove([bot.id]) }.not_to change { Group[:staff].user_count }
    end
  end

  describe "#remove" do
    before { manager.add([user.id, user2.id]) }

    it "removes users from group and returns removed user IDs" do
      result = manager.remove([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.count).to eq(0)
    end

    it "returns empty array for blank input" do
      expect(manager.remove([])).to eq([])
      expect(manager.remove(nil)).to eq([])
    end

    it "skips users who aren't members" do
      non_member = Fabricate(:user)

      events =
        DiscourseEvent.track_events(:user_removed_from_group) do
          expect(manager.remove([user.id, non_member.id])).to contain_exactly(user.id)
        end

      expect(events.map { |event| event[:params][0] }).to contain_exactly(user)
    end

    it "passes the acting user to each removed user's event" do
      admin = Fabricate(:admin)

      events =
        DiscourseEvent.track_events(:user_removed_from_group) do
          manager.remove([user.id, user2.id], acting_user: admin)
        end

      expect(events).to contain_exactly(
        { event_name: :user_removed_from_group, params: [user, group, { acting_user: admin }] },
        { event_name: :user_removed_from_group, params: [user2, group, { acting_user: admin }] },
      )
    end

    it "passes a nil acting user when none is given" do
      events = DiscourseEvent.track_events(:user_removed_from_group) { manager.remove([user.id]) }

      expect(events.first[:params].last).to eq(acting_user: nil)
    end

    context "when a concurrent removal deletes a member first" do
      fab!(:group_user_web_hook)

      before do
        user.update!(primary_group: group)
        group.update!(title: "Leader")
        user.update!(title: "Leader")

        allow(DB).to receive(:query_hash).and_wrap_original do |original, sql, *args, **kwargs|
          if sql.include?("DELETE FROM group_users")
            GroupUser.where(group:, user:).delete_all
            Group.update_counters(group.id, user_count: -1)
          end
          original.call(sql, *args, **kwargs)
        end
      end

      it "reports, announces and cleans up only the members it removed" do
        events = nil

        expect {
          events =
            DiscourseEvent.track_events(:user_removed_from_group) do
              expect(manager.remove([user.id, user2.id])).to contain_exactly(user2.id)
            end
        }.to change { group.reload.user_count }.from(2).to(0)

        expect(events.map { |event| event[:params][0] }).to contain_exactly(user2)
        removal_payloads =
          Jobs::EmitWebHookEvent
            .jobs
            .map { |job| job["args"].first }
            .select { |args| args["event_name"] == "user_removed_from_group" }
            .map { |args| JSON.parse(args["payload"]) }
        expect(removal_payloads).to contain_exactly(
          include("user_id" => user2.id, "group_id" => group.id),
        )
        expect(user.reload).to have_attributes(primary_group_id: group.id, title: "Leader")
      end
    end
  end
end
