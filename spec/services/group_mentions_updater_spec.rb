# frozen_string_literal: true

RSpec.describe GroupMentionsUpdater do
  fab!(:post)

  before { Jobs.run_immediately! }

  describe ".update" do
    it "rewrites group mentions in rendered and omitted form answers" do
      group = Fabricate(:group, name: "old_team", mentionable_level: Group::ALIAS_LEVELS[:everyone])
      template =
        Fabricate(
          :form_template,
          template: [
            { id: "visible", type: "textarea" },
            { id: "hidden", type: "textarea" },
          ].as_json.to_yaml,
          output_template: "{{ answers.visible }}",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "visible" => "Ask @old_team for help.",
            "hidden" => "Ask @old_team @old_team later; ignore old_team@example.com.",
          },
        )
      post.update!(raw: submission.normalized_raw, form_data: submission.to_h)
      hidden_submission =
        submission.with_answers(submission.answers.merge("visible" => "A note without a mention."))
      hidden_post =
        Fabricate(:post, raw: hidden_submission.normalized_raw, form_data: hidden_submission.to_h)

      group.update!(name: "new_team")

      expect(post.reload.form_submission.answers).to eq(
        "visible" => "Ask @new_team for help.",
        "hidden" => "Ask @new_team @new_team later; ignore old_team@example.com.",
      )
      expect(post.raw).to eq(post.form_submission.normalized_raw)
      expect(hidden_post.reload.form_submission.answers["hidden"]).to eq(
        post.form_submission.answers["hidden"],
      )
      expect(hidden_post.raw).to eq(hidden_submission.normalized_raw)
    end

    it "updates valid group mentions" do
      new_group_name = "awesome_team"
      old_group_name = "team"

      [
        ["@#{old_group_name} is awesome!", "@#{new_group_name} is awesome!"],
        ["This @#{old_group_name} is awesome!", "This @#{new_group_name} is awesome!"],
        ["Mention us @ @#{old_group_name}", "Mention us @ @#{new_group_name}"],
      ].each do |raw, expected_raw|
        group =
          Fabricate(:group, name: old_group_name, mentionable_level: Group::ALIAS_LEVELS[:everyone])

        post.update!(raw: raw)
        group.update!(name: new_group_name)
        post.reload

        expect(post.raw_mentions).to eq([new_group_name])
        expect(post.raw).to eq(expected_raw)

        group.destroy!
      end
    end

    it "does not update invalid group mentions" do
      group = Fabricate(:group, name: "team", mentionable_level: Group::ALIAS_LEVELS[:everyone])

      post.update!(raw: "This is not valid@team.com")

      expect(post.reload.raw_mentions).to eq([])

      group.update!(name: "new_team_name")

      expect(post.reload.raw_mentions).to eq([])
    end

    it "updates a category description that mentions the group" do
      group = Fabricate(:group, name: "old_team", mentionable_level: Group::ALIAS_LEVELS[:everyone])

      category = Fabricate(:category_with_definition)
      first_post = category.topic.first_post
      first_post.revise(first_post.user, { raw: "This category is managed by @old_team" })
      category.reload

      expect(category.description).to include("old_team")

      GroupMentionsUpdater.update("new_team", "old_team")
      category.reload

      expect(category.description).to include("new_team")
      expect(category.description).not_to include("old_team")
    end

    it "ignores validations" do
      everyone_mention_level = Group::ALIAS_LEVELS[:everyone]

      %w[awesome_team pro_team].each do |name|
        Fabricate(:group, name: name, mentionable_level: everyone_mention_level)
      end

      post.update!(raw: "@awesome_team is cool and so is @pro_team")

      SiteSetting.max_mentions_per_post = 1
      GroupMentionsUpdater.update("cool_team", "awesome_team")

      post.reload
      expect(post.raw_mentions).to match_array(%w[cool_team pro_team])
    end
  end
end
