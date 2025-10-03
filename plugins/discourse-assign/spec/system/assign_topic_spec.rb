# frozen_string_literal: true

describe "Assign | Assigning topics", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }
  fab!(:admin1) { Fabricate(:admin) }
  fab!(:admin2) { Fabricate(:admin) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.prioritize_full_name_in_ux = false
    SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
    SiteSetting.assign_allowed_on_groups = "#{Group::AUTO_GROUPS[:staff]}"

    sign_in(admin1)
  end

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
      describe "with open topic" do
        it "can assign and unassign" do
          visit "/t/#{topic.id}"

          topic_page.click_assign_topic
          assign_modal.assignee = admin2
          assign_modal.confirm

          expect(assign_modal).to be_closed

          expect(topic_page).to have_assigned(user: admin2, at_post: 2)
          expect(find("#topic .assigned-to")).to have_content(admin2.username)

          topic_page.click_unassign_topic

          expect(topic_page).to have_unassigned(user: admin2, at_post: 3)
          expect(page).to have_no_css("#topic .assigned-to")
        end

        it "can submit form with shortcut from texatea" do
          visit "/t/#{topic.id}"

          topic_page.click_assign_topic
          assign_modal.assignee = admin2

          find("body").send_keys(:tab)
          find("body").send_keys(:control, :enter)

          expect(assign_modal).to be_closed

          expect(topic_page).to have_assigned(user: admin2, at_post: 2)
          expect(find("#topic .assigned-to")).to have_content(admin2.username)
        end

        context "when prioritize_full_name_in_ux setting is enabled" do
          before { SiteSetting.prioritize_full_name_in_ux = true }

          it "shows the user's name after assign" do
            visit "/t/#{topic.id}"

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm
            expect(find("#topic .assigned-to")).to have_content(admin2.name)
          end

          it "show the user's username if there is no name" do
            visit "/t/#{topic.id}"
            admin2.name = nil
            admin2.save!
            admin2.reload

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm
            expect(find("#topic .assigned-to")).to have_content(admin2.username)
          end
        end

        context "when assigns are not public" do
          before { SiteSetting.assigns_public = false }

          it "assigned small action post has 'private-assign' in class attribute" do
            visit "/t/#{topic.id}"

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm

            expect(assign_modal).to be_closed
            expect(topic_page).to have_assigned(
              user: admin2,
              at_post: 2,
              class_attribute: ".private-assign",
            )
          end
        end

        context "when unassign_on_close is set to true" do
          before { SiteSetting.unassign_on_close = true }

          it "unassigns the topic on close" do
            visit "/t/#{topic.id}"

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm

            expect(assign_modal).to be_closed
            expect(topic_page).to have_assigned(user: admin2, at_post: 2)

            find(".timeline-controls .toggle-admin-menu").click
            find(".topic-admin-close").click

            expect(find("#post_3")).to have_content(
              I18n.t("js.action_codes.closed.enabled", when: "just now"),
            )
            expect(page).to have_no_css("#post_4")
            expect(page).to have_no_css("#topic .assigned-to")
          end

          it "can assign the previous assignee" do
            visit "/t/#{topic.id}"

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm

            expect(assign_modal).to be_closed
            expect(topic_page).to have_assigned(user: admin2, at_post: 2)

            find(".timeline-controls .toggle-admin-menu").click
            find(".topic-admin-close").click

            expect(find("#post_3")).to have_content(
              I18n.t("js.action_codes.closed.enabled", when: "just now"),
            )
            expect(page).to have_no_css("#post_4")
            expect(page).to have_no_css("#topic .assigned-to")

            topic_page.click_assign_topic
            assign_modal.assignee = admin2
            assign_modal.confirm

            expect(page).to have_no_css("#post_4")

            expect(find("#topic .assigned-to")).to have_content(admin2.username)
          end

          context "when reassign_on_open is set to true" do
            before { SiteSetting.reassign_on_open = true }

            it "reassigns the topic on open" do
              skip_on_ci!("Flaky test - reassigning topic on open")
              visit "/t/#{topic.id}"

              topic_page.click_assign_topic
              assign_modal.assignee = admin2
              assign_modal.confirm

              expect(assign_modal).to be_closed
              expect(topic_page).to have_assigned(user: admin2)

              find(".timeline-controls .toggle-admin-menu").click
              find(".topic-admin-close").click

              expect(find("#post_3")).to have_content(
                I18n.t("js.action_codes.closed.enabled", when: "just now"),
              )
              expect(page).to have_no_css("#post_4")
              expect(page).to have_no_css("#topic .assigned-to")

              find(".timeline-controls .toggle-admin-menu").click
              find(".topic-admin-open").click

              expect(find("#post_4")).to have_content(
                I18n.t("js.action_codes.closed.disabled", when: "just now"),
              )
              expect(page).to have_no_css("#post_5")
              try_until_success do
                expect(find("#topic .assigned-to")).to have_content(admin2.username)
              end
            end
          end
        end
      end
    end
  end
end
