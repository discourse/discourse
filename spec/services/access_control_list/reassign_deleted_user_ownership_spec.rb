# frozen_string_literal: true

RSpec.describe AccessControlList::ReassignDeletedUserOwnership do
  describe described_class::Contract, type: :model do
    it { is_expected.to allow_values(-2, -1, 0, 1, 42).for(:user_id) }
    it { is_expected.not_to allow_value(nil).for(:user_id) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_presence_of(:deleted_at) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:acting_user) { Discourse.system_user }
    fab!(:admin)
    fab!(:owner_acl) do
      Fabricate(:access_control_list_with_users, permission: "owner", users: [user])
    end

    let(:params) { { user_id: user.id, username: user.username, deleted_at: } }
    let(:deleted_at) { Time.zone.parse("2026-10-26T01:23:45Z") }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "with an invalid user ID" do
      let(:params) { super().merge(user_id: nil) }

      it { is_expected.to fail_a_contract }
    end

    context "when the actor is anonymous" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:is_system_actor) }
    end

    context "when the actor is an administrator" do
      fab!(:acting_user, :admin)

      it { is_expected.to fail_a_policy(:is_system_actor) }
    end

    context "when the user record has already been deleted" do
      let(:params) { super().merge(username: "DeletedSnapshotUsername") }

      before { User.where(id: user.id).delete_all }

      it "transfers ownership and audits the supplied identity snapshot" do
        expect(result).to run_successfully
        expect(owner_acl.reload.allowed_user_ids).to eq([admin.id])
        expect(UserHistory.last.context).to eq(
          "deleted_user_id: #{user.id}\ndeleted_username: #{params[:username]}\ndeleted_at: #{deleted_at.iso8601}",
        )
      end
    end

    context "when the departing user has a reserved negative ID" do
      fab!(:user) { Fabricate(:user, id: -123) }

      before { owner_acl.update!(allowed_user_ids: [user.id]) }

      it "transfers the reserved user's ownership to an admin" do
        expect(result).to run_successfully
        expect(owner_acl.reload.allowed_user_ids).to eq([admin.id])
      end
    end

    context "without owned ACLs" do
      before { owner_acl.update!(permission: "view") }

      it "succeeds without changing permissions or creating an audit entry" do
        expect { result }.not_to change(UserHistory, :count)
        expect(result).to run_successfully
        expect(owner_acl.reload.allowed_user_ids).to eq([user.id])
      end
    end

    context "with owned ACLs" do
      it "transfers ownership and records the departing user's identity" do
        expect { result }.to change { owner_acl.reload.allowed_user_ids }.from([user.id]).to(
          [admin.id],
        )
        expect(result).to run_successfully
        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:assume_access_control_ownership],
          acting_user_id: admin.id,
          target_user_id: admin.id,
          subject: "#{owner_acl.target_type} (#{owner_acl.target_id})",
          context:
            "deleted_user_id: #{user.id}\ndeleted_username: #{user.username}\ndeleted_at: #{deleted_at.iso8601}",
        )
      end

      it "selects the same eligible administrator for every owned target" do
        other_admin = Fabricate(:admin)
        other_acl = Fabricate(:access_control_list_with_users, permission: "owner", users: [user])
        Fabricate(:admin, active: false)
        Fabricate(:admin, suspended_till: 1.day.from_now)

        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:assume_access_control_ownership]).count
        }.by(2)
        expect(result).to run_successfully
        selected_admin_id = owner_acl.reload.allowed_user_ids.sole
        expect([admin.id, other_admin.id]).to include(selected_admin_id)
        expect(other_acl.reload.allowed_user_ids).to eq([selected_admin_id])
      end

      it "preserves other owners and the source without duplicating the selected admin" do
        coowner = Fabricate(:user)
        owner_acl.update!(allowed_user_ids: [user.id, coowner.id, admin.id], source: "extension")

        expect(result).to run_successfully
        expect(owner_acl.reload).to have_attributes(
          allowed_user_ids: [coowner.id, admin.id],
          source: "extension",
        )
      end

      it "does not transfer unrelated ACLs" do
        other_owner = Fabricate(:user)
        other_acl =
          Fabricate(:access_control_list_with_users, permission: "owner", users: [other_owner])

        expect(result).to run_successfully
        expect(other_acl.reload.allowed_user_ids).to eq([other_owner.id])
      end

      it "leaves ownership and audit records unchanged on a repeated call" do
        expect(result).to run_successfully

        expect { described_class.call(params:, **dependencies) }.not_to change(UserHistory, :count)
        expect(owner_acl.reload.allowed_user_ids).to eq([admin.id])
      end
    end

    context "without another eligible administrator" do
      before do
        admin.update!(active: false)
        user.update!(admin: true)
        Fabricate(:admin, suspended_till: 1.day.from_now)
      end

      it "uses the system user when the departing user is the only active admin" do
        expect(result).to run_successfully
        expect(owner_acl.reload.allowed_user_ids).to eq([Discourse.system_user.id])
        expect(UserHistory.last.acting_user_id).to eq(Discourse.system_user.id)
      end
    end
  end
end
