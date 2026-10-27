# frozen_string_literal: true

RSpec.describe DbHelper do
  fab!(:sidebar_url1) { Fabricate(:sidebar_url, name: "short-sidebar-url") }
  fab!(:sidebar_url2) { Fabricate(:sidebar_url, name: "another-sidebar-url") }
  let(:sidebar_url_name_limit) { SidebarUrl.columns_hash["name"].limit }
  let(:long_sidebar_url_name) { "a" * (sidebar_url_name_limit + 1) }

  describe ".remap" do
    it "preserves remapped upload URLs when a form is edited later" do
      old_url = "https://old.example.com/uploads/example.png"
      new_url = "https://new.example.com/uploads/example.png"
      template =
        Fabricate(
          :form_template,
          template: [
            { id: "image", type: "composer" },
            { id: "hidden", type: "composer" },
            { id: "description", type: "input" },
          ].as_json.to_yaml,
          output_template: "{{ answers.image }} {{ answers.description }}",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "image" => "![image](#{old_url})",
            "hidden" => old_url,
            "description" => "Before",
          },
        )
      post = Fabricate(:post, raw: submission.normalized_raw, form_data: submission.to_h)

      changed = submission.with_answers(submission.answers.merge("description" => "Second"))
      PostRevisor.new(post).revise!(
        post.user,
        { raw: changed.normalized_raw, form_data: changed.to_h },
        force_new_version: true,
      )

      DbHelper.remap(old_url, new_url)

      post.reload
      expect(post.raw).to include(new_url)
      edited =
        post.form_submission.with_answers(
          post.form_submission.answers.merge("description" => "After"),
        )
      expect(edited.normalized_raw).to include(new_url)
      expect(edited.answers["hidden"]).to eq(new_url)
      revision = post.revisions.last
      expect(revision.form_data_changes.map { |data| data.dig("answers", "hidden") }).to eq(
        [new_url, new_url],
      )
      expect(revision.modifications["raw"]).to all(include(new_url))
      expect(
        PostRevisor.new(post).revise!(
          post.user,
          { raw: edited.normalized_raw, form_data: edited.to_h },
        ),
      ).to eq(true)
      expect(post.reload.raw).to include(new_url)
    end

    it "keeps the original answers remapped when an edit ends the grace period" do
      SiteSetting.editing_grace_period = 60
      template =
        Fabricate(:form_template, template: [{ id: "link", type: "composer" }].as_json.to_yaml)
      original =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "link" => "https://old.example/one",
          },
        )
      post = Fabricate(:post, raw: original.normalized_raw, form_data: original.to_h)
      post.update_columns(last_editor_id: post.user_id)
      changed = original.with_answers({ "link" => "https://old.example/two" })
      expect(
        PostRevisor.new(post).revise!(
          post.user,
          { raw: changed.normalized_raw, form_data: changed.to_h },
          revised_at: post.updated_at + 1.second,
        ),
      ).to eq(true)
      expect(post.reload.version).to eq(1)

      DbHelper.remap("https://old.example", "https://new.example")

      changed = post.reload.form_submission.with_answers({ "link" => "https://new.example/three" })
      expect(
        PostRevisor.new(post).revise!(
          post.user,
          { raw: changed.normalized_raw, form_data: changed.to_h },
          force_new_version: true,
        ),
      ).to eq(true)
      expect(
        post.revisions.last.form_data_changes.map { |data| data.dig("answers", "link") },
      ).to eq(%w[https://new.example/one https://new.example/three])
    end

    it "respects table exclusions and anchors for saved form answers" do
      template =
        Fabricate(:form_template, template: [{ id: "link", type: "composer" }].as_json.to_yaml)
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "link" => "prefix old.example suffix",
          },
        )
      post = Fabricate(:post, raw: submission.normalized_raw, form_data: submission.to_h)

      DbHelper.remap("old.example", "new.example", excluded_tables: %w[posts])
      expect(post.reload.form_data).to eq(submission.to_h)
      expect(post.raw).to eq(submission.normalized_raw)

      DbHelper.remap("old.example", "new.example", anchor_left: true)
      expect(post.reload.form_data).to eq(submission.to_h)

      DbHelper.remap("prefix old.example", "new.example", anchor_left: true)
      expect(post.reload.form_submission.answers["link"]).to eq("new.example suffix")
      expect(post.raw).to eq(post.form_submission.normalized_raw)
    end

    it "remaps the columns" do
      post = Fabricate(:post, cooked: "this is a specialcode that I included")
      post_attributes = post.reload.attributes

      badge = Fabricate(:badge, query: "specialcode")
      badge_attributes = badge.reload.attributes

      DbHelper.remap("specialcode", "codespecial")

      post.reload

      expect(post.cooked).to include("codespecial")

      badge.reload

      expect(badge.query).to eq("codespecial")

      expect(badge_attributes.except("query")).to eq(badge.attributes.except("query"))
    end

    it "allows tables to be excluded from scanning" do
      post = Fabricate(:post, cooked: "test")

      DbHelper.remap("test", "something else", excluded_tables: %w[posts])

      expect(post.reload.cooked).to eq("test")
    end

    it "does not remap readonly columns" do
      post = Fabricate(:post, raw: "This is a test", cooked: "This is a test")

      Migration::ColumnDropper.mark_readonly("posts", "cooked")

      DbHelper.remap("test", "something else")

      post.reload

      expect(post.raw).to eq("This is a something else")
      expect(post.cooked).to eq("This is a test")

      DB.exec "DROP FUNCTION #{Migration::BaseDropper.readonly_function_name("posts", "cooked")} CASCADE"
    end

    context "when skip_max_length_violations is false" do
      it "raises an exception if remap exceeds column length constraint by default" do
        expect { DbHelper.remap("sidebar-url", long_sidebar_url_name) }.to raise_error(
          PG::StringDataRightTruncation,
          /value too long.*table: sidebar_urls,.*name/,
        )
      end
    end

    context "when skip_max_length_violations is true" do
      it "skips a remap eligible row if new value exceeds column length constraint" do
        DbHelper.remap("sidebar-url", long_sidebar_url_name, skip_max_length_violations: true)

        sidebar_url1.reload
        sidebar_url2.reload

        expect(sidebar_url1.name).to eq("short-sidebar-url")
        expect(sidebar_url2.name).to eq("another-sidebar-url")
      end

      it "logs skipped remaps due to max length constraints when verbose is true" do
        expect {
          DbHelper.remap(
            "sidebar-url",
            long_sidebar_url_name,
            verbose: true,
            skip_max_length_violations: true,
          )
        }.to output(/SKIPPED:/).to_stdout

        sidebar_url1.reload
        sidebar_url2.reload

        expect(sidebar_url1.name).to eq("short-sidebar-url")
        expect(sidebar_url2.name).to eq("another-sidebar-url")
      end

      it "protects each length-constrained column independently on the same row" do
        value_limit = SidebarUrl.columns_hash["value"].limit
        # name(80) will fit after remap, value(1000) will overflow.
        row =
          SidebarUrl.create!(
            icon: "link",
            name: "TOK-name",
            value: "TOK" + ("x" * (value_limit - 3)),
          )

        expect {
          DbHelper.remap("TOK", "TOKENEXPANDED", skip_max_length_violations: true)
        }.not_to raise_error

        row.reload
        expect(row.name).to eq("TOKENEXPANDED-name")
        expect(row.value).to eq("TOK" + ("x" * (value_limit - 3)))
      end
    end
  end

  describe ".regexp_replace" do
    it "uses PostgreSQL regex flags and backreferences in omitted answers" do
      template =
        Fabricate(
          :form_template,
          template: [{ id: "link", type: "composer" }].as_json.to_yaml,
          output_template: "The link is omitted.",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "link" => "OLD.example/123 OLD.example/456",
          },
        )
      post = Fabricate(:post, raw: submission.normalized_raw, form_data: submission.to_h)
      post.trash!

      DbHelper.regexp_replace('old\.example/([0-9]+)', 'new.example/\1', flags: "i")

      expect(post.reload.form_submission.answers["link"]).to eq("new.example/123 OLD.example/456")
      expect(post.raw).to eq(submission.normalized_raw)
    end

    it "remaps the columns" do
      post = Fabricate(:post, raw: "this is a [img]test[/img] post")

      DbHelper.regexp_replace("\\[img\\]test\\[/img\\]", "[img]something[/img]")

      expect(post.reload.raw).to include("[img]something[/img]")
    end

    context "when skip_max_length_violations is false" do
      it "raises an exception if regexp_replace exceeds column length constraint by default" do
        expect { DbHelper.regexp_replace("sidebar-url", long_sidebar_url_name) }.to raise_error(
          PG::StringDataRightTruncation,
          /value too long.*table: sidebar_urls,.*name/,
        )
      end
    end

    context "when skip_max_length_violations is true" do
      it "skips regexp_replace eligible rows if new value exceeds column length constraint" do
        DbHelper.regexp_replace(
          "sidebar-url",
          long_sidebar_url_name,
          skip_max_length_violations: true,
        )

        sidebar_url1.reload
        sidebar_url2.reload

        expect(sidebar_url1.name).to eq("short-sidebar-url")
        expect(sidebar_url2.name).to eq("another-sidebar-url")
      end

      it "logs skipped regexp_replace due to max length constraints when verbose is true" do
        expect {
          DbHelper.regexp_replace(
            "sidebar-url",
            long_sidebar_url_name,
            verbose: true,
            skip_max_length_violations: true,
          )
        }.to output(/SKIPPED:/).to_stdout

        sidebar_url1.reload
        sidebar_url2.reload

        expect(sidebar_url1.name).to eq("short-sidebar-url")
        expect(sidebar_url2.name).to eq("another-sidebar-url")
      end

      it "protects each length-constrained column independently on the same row" do
        value_limit = SidebarUrl.columns_hash["value"].limit
        row =
          SidebarUrl.create!(
            icon: "link",
            name: "TOK-name",
            value: "TOK" + ("x" * (value_limit - 3)),
          )

        expect {
          DbHelper.regexp_replace("TOK", "TOKENEXPANDED", skip_max_length_violations: true)
        }.not_to raise_error

        row.reload
        expect(row.name).to eq("TOKENEXPANDED-name")
        expect(row.value).to eq("TOK" + ("x" * (value_limit - 3)))
      end
    end
  end
end
