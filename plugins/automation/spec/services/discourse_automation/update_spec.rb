# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :automation_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:automation) { Fabricate(:automation, name: "Original Name", enabled: true) }

    let(:guardian) { admin.guardian }
    let(:params) { { automation_id: automation.id, name: "New Name" } }
    let(:dependencies) { { guardian: } }

    context "when user can't update an automation" do
      fab!(:user)
      let(:guardian) { user.guardian }

      it { is_expected.to fail_a_policy(:can_update_automation) }
    end

    context "when data is invalid" do
      before { params[:automation_id] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the automation is not found" do
      before { params[:automation_id] = 999 }

      it { is_expected.to fail_to_find_a_model(:automation) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the automation" do
        expect { result }.to change { automation.reload.name }.from("Original Name").to("New Name")
      end

      it "logs the action with changes" do
        expect { result }.to change {
          UserHistory.where(custom_type: "update_automation").count
        }.by(1)
        expect(UserHistory.last).to have_attributes(
          details: a_string_including("id: #{automation.id}", "name: Original Name → New Name"),
        )
      end

      it "does not log when no changes are made" do
        params[:name] = automation.name
        expect { result }.not_to change {
          UserHistory.where(custom_type: "update_automation").count
        }
      end
    end

    context "when changing enabled state" do
      let(:params) { { automation_id: automation.id, enabled: false } }

      it { is_expected.to run_successfully }

      it "updates the enabled state" do
        expect { result }.to change { automation.reload.enabled }.from(true).to(false)
      end

      it "logs the change" do
        result
        expect(UserHistory.last).to have_attributes(
          details: a_string_including("enabled: true → false"),
        )
      end
    end

    context "when changing script" do
      fab!(:automation) do
        Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME, enabled: true)
      end

      let(:params) { { automation_id: automation.id, script: "new_script" } }

      before do
        automation.upsert_field!(
          "execute_at",
          "date_time",
          { "value" => 1.hour.from_now.iso8601 },
          target: "trigger",
        )
      end

      it "clears fields and disables automation" do
        expect(automation.fields).not_to be_empty
        result
        expect(automation.reload).to have_attributes(enabled: false, trigger: nil)
        expect(automation.fields).to be_empty
      end
    end

    context "when updating fields" do
      fab!(:automation) do
        Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME)
      end

      let(:original_time) { 1.hour.from_now.iso8601 }
      let(:new_time) { 2.hours.from_now.iso8601 }
      let(:params) do
        {
          automation_id: automation.id,
          fields: [
            {
              name: "execute_at",
              component: "date_time",
              target: "trigger",
              metadata: {
                value: new_time,
              },
            },
          ],
        }
      end

      before do
        automation.upsert_field!(
          "execute_at",
          "date_time",
          { "value" => original_time },
          target: "trigger",
        )
      end

      it { is_expected.to run_successfully }

      it "updates the field" do
        result
        automation.reload
        expect(automation.trigger_field("execute_at")["value"]).to eq(new_time)
      end

      it "logs field changes" do
        result
        expect(UserHistory.last).to have_attributes(
          details: a_string_including("execute_at: #{original_time} → #{new_time}"),
        )
      end
    end
  end
end
