# frozen_string_literal: true

RSpec.describe "Editable form submissions" do
  fab!(:user, :admin)
  fab!(:form_template) do
    Fabricate(
      :form_template,
      template: [
        {
          id: "description",
          type: "input",
          attributes: {
            label: "Description",
          },
          validations: {
            required: true,
          },
        },
        {
          id: "seats",
          type: "input",
          attributes: {
            label: "Seats",
          },
          validations: {
            type: "number",
          },
        },
        { id: "confirmed", type: "checkbox", attributes: { label: "Confirmed" } },
        {
          id: "options",
          type: "multi-select",
          attributes: {
            label: "Options",
          },
          choices: [1, 2, 3],
        },
      ].as_json.to_yaml,
    )
  end
  fab!(:category) { Fabricate(:category, form_template_ids: [form_template.id]) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:drafts_page) { PageObjects::Pages::UserActivityDrafts.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.enable_form_templates = true
    SiteSetting.show_preview_for_form_templates = false
    sign_in(user)
  end

  it "restores an incomplete form draft after closing and reloading without preview" do
    visit "/new-topic?category_id=#{category.id}"
    expect(page).to have_css("#form-template-form")
    find("input[name='seats']").fill_in(with: "0")
    find("select[name='options']").select("1")
    find("select[name='options']").select("3")
    composer.discard
    discard_modal = PageObjects::Modals::DiscardDraft.new
    expect(discard_modal).to be_open
    discard_modal.click_cancel
    composer.close
    expect(composer).to be_closed

    drafts_page.visit(user)
    expect(drafts_page).to have_drafts(count: 1)
    find(".post-list-item .draft-title").click
    expect(page).to have_field("seats", with: "0")
    expect(page).to have_select("options", selected: %w[1 3])
    expect(page).to have_unchecked_field("confirmed")
    expect(page).to have_field("description", with: "")
  end

  it "reopens and edits a published form using its saved definition" do
    submission =
      FormTemplate::Submission.from_template(
        form_template,
        answers: {
          "description" => "An original sufficiently long description.",
          "seats" => "0",
          "confirmed" => false,
          "options" => %w[1 3],
        },
      )
    form_post =
      Fabricate(:post, user:, post_number: 1, raw: submission.render, form_data: submission.to_h)
    form_template.destroy!
    topic_page.visit_topic(form_post.topic)
    topic_page.click_post_action_button(form_post, :edit)
    expect(page).to have_field("description", with: submission.answers["description"])
    expect(page).to have_select("options", selected: %w[1 3])
    composer.discard
    expect(composer).to be_closed
    expect(PageObjects::Modals::DiscardDraft.new).to be_closed
    topic_page.click_post_action_button(form_post, :edit)
    find("input[name='description']").fill_in(with: "An updated sufficiently long description.")
    composer.submit
    expect(composer).to be_closed
    expect(topic_page).to have_post_content(
      post_number: 1,
      content: "An updated sufficiently long description.",
    )
    topic_page.click_post_action_button(form_post, :edit)
    expect(page).to have_field("description", with: "An updated sufficiently long description.")
  end

  it "preserves absent and null answers while removing a saved upload" do
    fields = YAML.safe_load(form_template.template)
    fields << { "id" => "files", "type" => "upload", "attributes" => { "allow_multiple" => true } }
    fields << { "id" => "notes", "type" => "input" }
    fields << {
      "id" => "game",
      "type" => "tag-chooser",
      "attributes" => {
        "multiple" => true,
      },
      "choices" => [],
    }
    form_template.update!(template: fields.to_yaml)
    first_file = "[first.pdf|attachment](https://example.com/first.pdf) (1 KB)"
    second_file = "[second.pdf|attachment](https://example.com/second.pdf) (2 KB)"
    answers = {
      "description" => "An original sufficiently long description.",
      "confirmed" => nil,
      "notes" => nil,
      "options" => [],
      "files" => "#{first_file}\n#{second_file}",
    }
    submission = FormTemplate::Submission.from_template(form_template, answers:)
    form_post =
      Fabricate(:post, user:, post_number: 1, raw: submission.render, form_data: submission.to_h)
    topic_page.visit_topic(form_post.topic)
    topic_page.click_post_action_button(form_post, :edit)
    expect(page).to have_field("notes", with: "")
    composer.discard
    expect(composer).to be_closed
    expect(PageObjects::Modals::DiscardDraft.new).to be_closed

    topic_page.click_post_action_button(form_post, :edit)
    first(".form-template-field__remove-upload").click
    composer.close
    expect(composer).to be_closed
    drafts_page.visit(user)
    find(".post-list-item .resume-draft").click
    expect(page).to have_css(".form-template-field__uploaded-files li", count: 1)
    composer.submit
    expect(composer).to be_closed
    expect(form_post.reload.form_data["answers"]).to eq(answers.merge("files" => second_file))
    expect(form_post.raw).not_to include(first_file)
  end
end
