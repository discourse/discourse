# frozen_string_literal: true

RSpec.describe Jobs::ChangeDisplayName do
  before { stub_image_size }

  let(:username) { "codinghorror" }
  let(:old_display_name) { "|| Jeff ||" }
  let(:new_display_name) { "|| Mr. Atwood ||" }

  let(:user) { Fabricate(:user, username: username, name: old_display_name) }
  let(:topic) { Fabricate(:topic, user: user) }
  let!(:post) { create_post(post_attributes.merge(topic_id: topic.id)) }

  let!(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
  let(:avatar_url) { user.avatar_template_url.gsub("{size}", "48") }

  let(:post_attributes) { { raw: <<~RAW } }
    [quote="#{old_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
    quoted post
    [/quote]
  RAW

  let(:revised_post_attributes) { { raw: <<~RAW } }
    [quote="#{old_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
    quoted post
    [/quote]
    Forgot something.
  RAW

  let(:args) { { user_id: user.id, old_name: old_display_name, new_name: new_display_name } }

  describe "#execute" do
    it "rewrites quotes in deleted forms with incomplete required answers" do
      upload = Fabricate(:upload)
      template =
        Fabricate(
          :form_template,
          template: [
            { id: "quote", type: "composer" },
            { id: "attachment", type: "upload", validations: { required: true } },
          ].as_json.to_yaml,
          output_template: "{{ answers.quote }}",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "quote" => post_attributes[:raw],
            "attachment" => upload.to_markdown,
          },
        )
      saved = create_post(raw: submission.render, form_data: submission.to_h)
      saved.trash!
      cleaned =
        submission.with_answers(submission.answers.merge("attachment" => ""), validate: false)
      saved.update_columns(raw: cleaned.normalized_raw, form_data: cleaned.to_h)

      described_class.new.execute(args)

      expect(saved.reload.form_submission.answers["quote"]).to include(new_display_name)
      expect(saved.raw).to include(new_display_name)
      expect(saved.cooked).to include(new_display_name)
      expect(saved.form_submission.answers["attachment"]).to eq("")
    end

    it "keeps form answers and revisions aligned with quote display names" do
      template =
        Fabricate(
          :form_template,
          template: [{ id: "quote", type: "composer" }].as_json.to_yaml,
          output_template: "{% if answers.quote %}{{ answers.quote | strip }}{% endif %}",
        )
      original =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "quote" => post_attributes[:raw],
          },
        )
      saved = create_post(raw: original.render, form_data: original.to_h)
      changed = original.with_answers({ "quote" => revised_post_attributes[:raw] })
      PostRevisor.new(saved).revise!(
        saved.user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )

      described_class.new.execute(args)

      expect(saved.reload.raw).to include(new_display_name)
      expect(saved.form_submission.render).to eq(saved.raw)
      expect(saved.form_submission.answers["quote"]).to include(new_display_name)
      expect(
        saved.revisions.last.form_data_changes.map { |data| data.dig("answers", "quote") },
      ).to all(include(new_display_name))
    end

    it "updates hidden quote answers in live forms and historical snapshots" do
      template =
        Fabricate(
          :form_template,
          template: [
            { id: "quote", type: "composer" },
            { id: "show_quote", type: "checkbox" },
          ].as_json.to_yaml,
          output_template:
            "{% if answers.show_quote %}{{ answers.quote | strip }}{% else %}Quote is hidden.{% endif %}",
        )
      original =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "quote" => post_attributes[:raw],
            "show_quote" => false,
          },
        )
      saved = create_post(raw: original.render, form_data: original.to_h)
      changed =
        original.with_answers({ "quote" => revised_post_attributes[:raw], "show_quote" => false })
      PostRevisor.new(saved).revise!(
        saved.user,
        { raw: changed.render, form_data: changed.to_h },
        force_new_version: true,
      )
      expect(QuotedPost.where(post_id: saved.id)).to be_empty
      other_user = Fabricate(:user, name: old_display_name)
      other_quoted_post =
        Fabricate(:post, user: other_user, raw: "Another quoted post.", post_number: 1)
      unrelated_quote = <<~RAW
        [quote="#{old_display_name}, post:1, topic:#{other_quoted_post.topic_id}, username:#{other_user.username}"]
        Another quoted post.
        [/quote]
      RAW
      unrelated =
        original.with_answers(
          { "quote" => "#{unrelated_quote}\nPlain text about #{username}.", "show_quote" => false },
        )
      unrelated_post = create_post(raw: unrelated.render, form_data: unrelated.to_h)

      described_class.new.execute(args)

      expect(unrelated_post.reload.form_data).to eq(unrelated.to_h)
      expect(saved.reload.raw).to eq(original.render)
      expect(saved.form_submission.answers["quote"]).to include(new_display_name)
      snapshots =
        saved.revisions.last.form_data_changes.map { |data| FormTemplate::Submission.new(data) }
      expect(snapshots.map { |snapshot| snapshot.answers["quote"] }).to all(
        include(new_display_name),
      )
      expect(
        [saved.form_submission, *snapshots].map do |snapshot|
          snapshot.with_answers(snapshot.answers.merge("show_quote" => true)).render
        end,
      ).to all(include(new_display_name))
    end

    context "when the renamed user has been quoted" do
      it "rewrites the raw quote display name" do
        expect { described_class.new.execute(args) }.to change { post.reload.raw }.to(<<~RAW.strip)
          [quote="#{new_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
          quoted post
          [/quote]
        RAW
      end

      it "rewrites the cooked quote display name" do
        expect { described_class.new.execute(args) }.to change { post.reload.cooked }.to(
          match_html(<<~HTML.strip),
          <aside class="quote no-group" data-username="#{username}" data-display-name="#{new_display_name}" data-post="1" data-topic="#{quoted_post.topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt="" width="24" height="24" src="#{avatar_url}" class="avatar"> #{new_display_name}:</div>
          <blockquote>
          <p>quoted post</p>
          </blockquote>
          </aside>
        HTML
        )
      end
    end

    context "when the user has been quoted in revisions" do
      before { post.revise(post.user, revised_post_attributes, force_new_version: true) }

      it "rewrites the quote in revisions" do
        expect { described_class.new.execute(args) }.to change {
          post.reload.revisions[0].modifications["raw"][0]
        }.to(<<~RAW.strip)
          [quote="#{new_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
          quoted post
          [/quote]
          RAW
      end
    end

    context "when names are disabled and a user changes their name from their username to a real name" do
      let(:old_display_name) { username }
      let(:new_display_name) { "Jeff Atwood" }

      let(:post_attributes) { { raw: <<~RAW } }
        [quote="#{username}, post:1, topic:#{quoted_post.topic.id}"]
        quoted post
        [/quote]
      RAW

      before do
        SiteSetting.enable_names = false
        with_search_indexer_enabled { SearchIndexer.index(post, force: true) }
        user.update!(name: new_display_name)
      end

      it "does not add the new real name to the post search index" do
        with_search_indexer_enabled { described_class.new.execute(args) }

        expect(post.reload.post_search_data.raw_data).not_to include(new_display_name)
      end
    end
  end
end
