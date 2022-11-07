# frozen_string_literal: true

require Rails.root.join('script/import_scripts/base')

RSpec.describe "ImportScripts::FluxBB" do
  let(:expected_sqls) {
    {}
  }

  class MockMySQLClient
    def initialize(sql_matchers)
      @sql_matchers = sql_matchers
    end

    def query(sql, cache_rows:)
      @sql_matchers.each do |sql_matcher_regex, sql_mock_result|
        if Regexp.new(sql_matcher_regex, Regexp::MULTILINE).match?(sql)
          return sql_mock_result
        end
      end
      []
    end
  end

  if ENV["IMPORT"] == "1"
    before do
      STDOUT.stubs(:write)

      # Because this script does "ImportScripts::FluxBB.new.perform" at the end
      # we need stubs to allow the 'new' method to work and to nullify 'perform'
      # before we can require it
      Mysql2::Client.stubs(:new).returns(MockMySQLClient.new(expected_sqls))
      ImportScripts::Base.define_method(:perform) {}
      require Rails.root.join('script/import_scripts/fluxbb')
    end

    describe "#execute" do
      context "when all database queries return nothing" do
        let(:expected_sqls) { {
          'count\(\*\)' => [ { 'count' => 0 } ]
        } }
        it "succeeds but without importing anything" do
          expect {
            ImportScripts::FluxBB.new.execute
          }.to_not change { Post.count }
        end
      end
    end

    describe "#import_posts" do
      let(:example_post_content) { "My post content" }

      let(:example_post_data) { {
        "id" => 123,
        "first_post_id" => 123,
        "title" => "My post title",
        "raw" => example_post_content,
        "created_at" => 1234
      } }

      let(:expected_sqls) { {
        'count\(\*\).* from .*posts' => [ { 'count' => 1 } ],
        'id.*topic_id.*category_id.*FROM.*posts.*topics.*OFFSET 0' => [ example_post_data ]
      } }

      it "imports a post" do
        expect {
          ImportScripts::FluxBB.new.import_posts
        }.to change { Post.count }.by(1)

        expect(Post.last.raw).to eq(example_post_content)
      end

      context("when initialised with the bbcode_to_md flag") do
        before do
          importer = ImportScripts::FluxBB.new
          importer.instance_variable_set(:@bbcode_to_md, true)

          importer.import_posts
        end

        context "with bbcode syntax examples to be converted" do
          let(:example_post_content) {
            "[b]Bold text[/b]\n" +
            "[i]Italic text[/i]\n" +
            "[url=https://www.discourse.org/]Link with link text[/url]\n" +
            "[url]https://www.discourse.org/[/url] - Link without link text\n" +
            "[url=/about]Relative link[/url]\n" +
            "=) =| =( =D :o :lol: :mad: :rolleyes:\n" +
            "=)=) Smiley whitespace=) https://awkward.com?x=D :mad::mad::mad:"
          }

          it "converts bbcode to markdown in the resulting Post" do
            expect(Post.last.raw).to eq(
              "**Bold text**\n" +
              "*Italic text*\n" +
              "[Link with link text](https://www.discourse.org/)\n" +
              "[https://www.discourse.org/](https://www.discourse.org/) - Link without link text\n" +
              "[Relative link](/about)\n" +
              ":) :| :( :D :O :laughing: :rage: :roll_eyes:\n" +
              ":)=) Smiley whitespace=) https://awkward.com?x=D :rage::mad::mad:"
            )
          end
        end

        context "with bbcode examples which are best left in bbcode format" do
          let(:example_post_content) {
            "[code]Code[/code]\n" +
            "[quote=James]This is the text I want to quote.[/quote]\n" +
            "[quote]This is the text I want to quote.[/quote] \n" +
            ":) :| :( :D :O ;) :/ :P :p :cool:"
          }

          it "does no conversion leaving discourse to handle the bbcode" do
            expect(Post.last.raw).to eq(example_post_content)
          end
        end

        context "with color bbcode examples which have no support in discourse" do
          let(:example_post_content) {
            "[color=#FF0000]Red text[/color]\n" +
            "[color=blue]Blue text[/color]"
          }

          it "drops the unsupported bbcode leaving plain unformatted text" do
            expect(Post.last.raw).to eq(
              "Red text\n" +
              "Blue text"
            )
          end
        end

        context "with FluxBB internal linking syntax which will be hard to convert" do
          let(:example_post_content) {
            "[topic=1]Internal link to fluxbb topic with link text[/topic]\n" +
            "[topic]1[/topic] - Internal link to fluxbb topic without link text\n" +
            "[post=1]Internal link to fluxbb post with link text[/post]\n" +
            "[post]1[/post] - Internal link to fluxbb post without link text\n" +
            "[forum=1]Internal link to fluxbb forum with link text[/forum]\n" +
            "[forum]1[/forum] - Internal link to fluxbb forum without link text\n" +
            "[user=2]Internal link to fluxbb user profile with link text[/user]\n" +
            "[user]2[/user] - Internal link to fluxbb user without link text"
          }

          it "does no conversion leaving bbcode in place for manual conversion" do
            expect(Post.last.raw).to eq(example_post_content)
          end
        end

        context "with fluxbb bbcode syntax examples which are not yet working!" do
          let(:example_post_content) {
            "[u]Underlined text[/u]\n" +
            "[s]Strike-through text[/s]\n"
            "[del]Deleted text[/del]\n" +
            "[ins]Inserted text[/ins]\n" +
            "[em]Emphasised text[/em]\n" +
            "[h]Heading[/h]\n" +
            "[list][*]Example list item 1.[/*][*]Example list item 2.[/*][*]Example list item 3.[/*][/list]\n" +
            "[list=1][*]Example list item 1.[/*][*]Example list item 2.[/*][*]Example list item 3.[/*][/list]\n" +
            "[email]myname@example.com[/email] - email link without link text\n" +
            "[email=myname@example.com]Email link with link text[/email]"
          }

          xit "converts bbcode to markdown in the resulting Post" do
            expect(Post.last.raw).to eq(
              "[u]Underlined text[/u]\n" + #should be unaltered!
              "~~Strike-through text~~\n" +
              "<del>Deleted text</del>\n" +
              "<ins>Inserted text<ins>\n" +
              "*Emphasised text*\n" +
              "## Heading\n" +
              "<ul><li>Example list item 1.</li><li>Example list item 2.</li><li>Example list item 3.</li></ul>\n" +
              "<ol><li>Example list item 1.</li><li>Example list item 2.</li><li>Example list item 3.</li></ol>\n" +
              "[mailto:myname@example.com](mailto:myname@example.com) - email link without link text\n" +
              "[Email link with link text](mailto:myname@example.com)"
            )
          end
        end
      end
    end
  end
end
