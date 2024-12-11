# frozen_string_literal: true

RSpec.describe DbHelper do
  fab!(:sidebar_url1) { Fabricate(:sidebar_url, name: "short-sidebar-url") }
  fab!(:sidebar_url2) { Fabricate(:sidebar_url, name: "another-sidebar-url") }
  let(:sidebar_url_name_limit) { SidebarUrl.columns_hash["name"].limit }
  let(:long_sidebar_url_name) { "a" * (sidebar_url_name_limit + 1) }

  describe ".remap" do
    it "should remap columns properly" do
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
    end
  end

  describe ".regexp_replace" do
    it "should remap columns correctly" do
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
    end
  end
end
