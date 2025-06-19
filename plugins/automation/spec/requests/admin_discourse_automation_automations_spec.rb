# frozen_string_literal: true

describe DiscourseAutomation::AdminAutomationsController do
  fab!(:automation)

  before do
    SiteSetting.discourse_automation_enabled = true

    I18n.backend.store_translations(
      :en,
      {
        discourse_automation: {
          scriptables: {
            something_about_us: {
              title: "Something about us.",
              description: "We rock!",
            },
          },
          triggerables: {
            title: "Triggerables",
            description: "Triggerables",
          },
        },
      },
    )
  end

  after { I18n.backend.reload! }

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "shows the automation" do
        get "/admin/plugins/automation/automations/#{automation.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["automation"]["id"]).to eq(automation.id)
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        get "/admin/plugins/automation/automations/#{automation.id}.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#create" do
    let(:script) { "forced_triggerable" }

    before do
      DiscourseAutomation::Scriptable.add(script) do
        triggerable! :recurring, { recurrence: { interval: 1, frequency: "day" } }
      end
    end

    after { DiscourseAutomation::Scriptable.remove(script) }

    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "creates the 'forced triggerable' automation" do
        post "/admin/plugins/automation/automations.json",
             params: {
               automation: {
                 name: "foobar",
                 script:,
               },
             }
        expect(response.status).to eq(200)
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        post "/admin/plugins/automation/automations.json",
             params: {
               automation: {
                 name: "foobar",
                 script:,
               },
             }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "updates the automation" do
        put "/admin/plugins/automation/automations/#{automation.id}.json",
            params: {
              automation: {
                trigger: "another-trigger",
              },
            }
        expect(response.status).to eq(200)
      end

      describe "invalid field’s component" do
        it "errors" do
          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: automation.script,
                  trigger: automation.trigger,
                  fields: [{ name: "foo", component: "bar" }],
                },
              }

          expect(response.status).to eq(422)
        end
      end

      context "with required field" do
        before do
          DiscourseAutomation::Scriptable.add("test_required") do
            field :foo, component: :text, required: true
          end

          automation.update!(script: "test_required")
        end

        it "errors" do
          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: automation.script,
                  trigger: automation.trigger,
                  fields: [
                    { name: "foo", component: "text", target: "script", metadata: { value: nil } },
                  ],
                },
              }
          expect(response.status).to eq(422)
        end
      end

      context "when only changing enabled state" do
        it "updates only the enabled state" do
          original_trigger = automation.trigger
          original_script = automation.script
          expect(automation.enabled).to eq(true)

          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  enabled: false,
                },
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["automation"]["enabled"]).to eq(false)
          automation.reload
          expect(automation.enabled).to eq(false)
          expect(automation.trigger).to eq(original_trigger)
          expect(automation.script).to eq(original_script)
        end
      end

      context "when changing trigger and script of an enabled automation" do
        it "forces the automation to be disabled" do
          expect(automation.enabled).to eq(true)

          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: "bar",
                  trigger: "foo",
                  enabled: true,
                },
              }

          expect(automation.reload.enabled).to eq(false)
        end
      end

      context "when changing trigger of an enabled automation" do
        it "forces the automation to be disabled" do
          expect(automation.enabled).to eq(true)

          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: automation.script,
                  trigger: "foo",
                  enabled: true,
                },
              }

          expect(automation.reload.enabled).to eq(false)
        end
      end

      context "when changing script of an enabled automation" do
        it "disables the automation" do
          expect(automation.enabled).to eq(true)

          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  trigger: automation.trigger,
                  script: "foo",
                  enabled: true,
                },
              }

          expect(automation.reload.enabled).to eq(false)
        end
      end

      context "with invalid field’s metadata" do
        it "errors" do
          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: automation.script,
                  trigger: automation.trigger,
                  fields: [{ name: "sender", component: "users", metadata: { baz: 1 } }],
                },
              }

          expect(response.status).to eq(422)
        end
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        put "/admin/plugins/automation/automations/#{automation.id}.json",
            params: {
              automation: {
                trigger: "another-trigger",
              },
            }
        expect(response.status).to eq(404)
      end
    end

    context "when updating a point_in_time automation" do
      fab!(:automation) do
        Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME)
      end

      before do
        sign_in(Fabricate(:admin))

        automation.upsert_field!(
          "execute_at",
          "date_time",
          { value: 1.hours.from_now },
          target: "trigger",
        )
      end

      it "updates the associated pending automation execute_at" do
        expect(automation.pending_automations.count).to eq(1)
        expect(automation.pending_automations.last.execute_at).to be_within_one_minute_of(
          1.hours.from_now,
        )

        expect {
          put "/admin/plugins/automation/automations/#{automation.id}.json",
              params: {
                automation: {
                  script: automation.script,
                  trigger: automation.trigger,
                  fields: [
                    {
                      name: "execute_at",
                      component: "date_time",
                      target: "trigger",
                      metadata: {
                        value: 2.hours.from_now,
                      },
                    },
                  ],
                },
              }
        }.not_to change { automation.pending_automations.count }

        expect(automation.pending_automations.reload.last.execute_at).to be_within_one_minute_of(
          2.hours.from_now,
        )
      end
    end
  end

  describe "#index" do
    fab!(:automation1) { Fabricate(:automation, name: "First Automation") }
    fab!(:automation2) { Fabricate(:automation, name: "Second Automation") }

    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "returns a list of automations" do
        get "/admin/plugins/automation/automations.json"

        expect(response.status).to eq(200)

        parsed_response = response.parsed_body
        expect(parsed_response["automations"].length).to eq(3) # includes the default automation

        automation_names = parsed_response["automations"].map { |a| a["name"] }
        expect(automation_names).to include(automation1.name)
        expect(automation_names).to include(automation2.name)
      end

      it "doesn't include stats by default" do
        get "/admin/plugins/automation/automations.json"

        expect(response.status).to eq(200)

        parsed_response = response.parsed_body
        automation_response = parsed_response["automations"].find { |a| a["id"] == automation1.id }

        expect(automation_response.key?("stats")).to eq(false)
      end

      context "with stats" do
        before do
          # Create some stats for automation1
          freeze_time DateTime.parse("2023-01-01")

          # Create stats for today (within last day)
          DiscourseAutomation::Stat.log(automation1.id, 0.5)
          DiscourseAutomation::Stat.log(automation1.id, 1.5)

          # Create stats for 3 days ago (within last week)
          freeze_time DateTime.parse("2022-12-29")
          DiscourseAutomation::Stat.log(automation1.id, 2.0)

          # Create stats for 15 days ago (within last month)
          freeze_time DateTime.parse("2022-12-17")
          DiscourseAutomation::Stat.log(automation2.id, 3.0)

          # Return to present
          freeze_time DateTime.parse("2023-01-01")
        end

        it "includes stats in the response" do
          get "/admin/plugins/automation/automations.json"

          expect(response.status).to eq(200)

          parsed_response = response.parsed_body
          automation1_response =
            parsed_response["automations"].find { |a| a["id"] == automation1.id }
          automation2_response =
            parsed_response["automations"].find { |a| a["id"] == automation2.id }

          # Verify stats exist
          expect(automation1_response["stats"]).to be_present
          expect(automation2_response["stats"]).to be_present

          # Verify periods
          expect(automation1_response["stats"]["last_day"]).to be_present
          expect(automation1_response["stats"]["last_week"]).to be_present
          expect(automation1_response["stats"]["last_month"]).to be_present

          # Verify specific values for automation1
          expect(automation1_response["stats"]["last_day"]["total_runs"]).to eq(2)
          expect(automation1_response["stats"]["last_day"]["total_time"]).to eq(2.0)
          expect(automation1_response["stats"]["last_day"]["average_run_time"]).to eq(1.0)
          expect(automation1_response["stats"]["last_day"]["min_run_time"]).to eq(0.5)
          expect(automation1_response["stats"]["last_day"]["max_run_time"]).to eq(1.5)

          expect(automation1_response["stats"]["last_week"]["total_runs"]).to eq(3)

          # Verify specific values for automation2
          expect(automation2_response["stats"]["last_month"]["total_runs"]).to eq(1)
          expect(automation2_response["stats"]["last_month"]["total_time"]).to eq(3.0)
        end
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        get "/admin/plugins/automation/automations.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#destroy" do
    fab!(:automation)

    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "destroys the automation" do
        delete "/admin/plugins/automation/automations/#{automation.id}.json"
        expect(DiscourseAutomation::Automation.find_by(id: automation.id)).to eq(nil)
      end

      context "when the automation is not found" do
        it "raises a 404" do
          delete "/admin/plugins/automation/automations/999.json"
          expect(response.status).to eq(404)
        end
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        delete "/admin/plugins/automation/automations/#{automation.id}.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
