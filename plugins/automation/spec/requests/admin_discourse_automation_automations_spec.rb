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
        get "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["automation"]["id"]).to eq(automation.id)
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        get "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
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
        post "/admin/plugins/discourse-automation/automations.json",
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
        post "/admin/plugins/discourse-automation/automations.json",
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
        put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
            params: {
              automation: {
                trigger: "another-trigger",
              },
            }
        expect(response.status).to eq(200)
      end

      describe "invalid field’s component" do
        it "errors" do
          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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
          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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

      context "when changing trigger and script of an enabled automation" do
        it "forces the automation to be disabled" do
          expect(automation.enabled).to eq(true)

          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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

          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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

          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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
          put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
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
        put "/admin/plugins/discourse-automation/automations/#{automation.id}.json",
            params: {
              automation: {
                trigger: "another-trigger",
              },
            }
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#destroy" do
    fab!(:automation)

    context "when logged in as an admin" do
      before { sign_in(Fabricate(:admin)) }

      it "destroys the automation" do
        delete "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
        expect(DiscourseAutomation::Automation.find_by(id: automation.id)).to eq(nil)
      end

      context "when the automation is not found" do
        it "raises a 404" do
          delete "/admin/plugins/discourse-automation/automations/999.json"
          expect(response.status).to eq(404)
        end
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        delete "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
