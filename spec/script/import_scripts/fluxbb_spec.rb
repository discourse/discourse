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
            "Paragraph test.\n\nPara2.\n\n[b][i]Para 3.\n\nPara 4.[/i][/b]\n\nPara 5.\n" +
            "[s]Strike-through text[/s]\n" +
            "[del]Deleted text[/del]\n" +
            "[ins]Inserted text[/ins]\n" +
            "[em]Emphasised text[/em]\n" +
            "[h]Heading[/h]\n" +
            "[h]Heading[/h]Text on the same line\n" +
            "[h]Heading\nOn two lines[/h]\n" +
            "[url=https://www.discourse.org/]Link with link text[/url]\n" +
            "[url]https://www.discourse.org/[/url] - Link without link text\n" +
            "[url=/about]Relative link[/url]\n" +
            "[post=234]Internal link to fluxbb post with link text[/post]\n" +
            "[post]234[/post] - Internal link to fluxbb post without link text\n" +
            "[topic=345]Internal link to fluxbb topic with link text[/topic]\n" +
            "[topic]345[/topic] - Internal link to fluxbb topic without link text\n" +
            "[forum=456]Internal link to fluxbb forum with link text[/forum]\n" +
            "[forum]456[/forum] - Internal link to fluxbb forum without link text\n" +
            "[user=567]Internal link to fluxbb user profile with link text[/user]\n" +
            "[user]567[/user] - Internal link to fluxbb user without link text\n" +
            "[img]http://www.ruby-lang.org/images/header-ruby-logo.png[/img]\n" +
            "[img=FluxBB allows alt text]http://www.ruby-lang.org/images/header-ruby-logo.png[/img]\n" +
            "[list][*]Example list item 1.[/*][*]Example list item 2.[/*][*]Example list item 3.[/*][/list]\n" +
            "[list=1][*]Example list item 1.[/*][*]Example list item 2.[/*][*]Example list item 3.[/*][/list]\n" +
            "[list=a][*]Example list item 1.[/*][*]Example list item 2.[/*][*]Example list item 3.[/*][/list]\n" +
            "[list][*]Example list items[*]with unclosed[*]list item tags[/list]\n" +
            "=) =| =( =D :o :lol: :mad: :rolleyes:\n" +
            "=)=) Smiley whitespace=) https://awkward.com?x=D :mad::mad::mad:"
          }

          it "converts bbcode to markdown in the resulting Post" do
            expect(Post.last.raw).to eq(
              "**Bold text**\n" +
              "*Italic text*\n" +
              "Paragraph test.\n\nPara2.\n\n***Para 3.\n<br>Para 4.***\n\nPara 5.\n" +
              "~~Strike-through text~~\n" +
              "<del>Deleted text</del>\n" +
              "<ins>Inserted text</ins>\n" +
              "**Emphasised text**\n" +
              "\n## Heading\n\n" +
              "\n## Heading\nText on the same line\n" +
              "\n## Heading<br>On two lines\n\n" +
              "[Link with link text](https://www.discourse.org/)\n" +
              "[https://www.discourse.org/](https://www.discourse.org/) - Link without link text\n" +
              "[Relative link](/about)\n" +
              "[Internal link to fluxbb post with link text](/viewtopic.php?pid=234#p234)\n" +
              "[234](/viewtopic.php?pid=234#p234) - Internal link to fluxbb post without link text\n" +
              "[Internal link to fluxbb topic with link text](/viewtopic.php?id=345)\n" +
              "[345](/viewtopic.php?id=345) - Internal link to fluxbb topic without link text\n" +
              "[Internal link to fluxbb forum with link text](/viewforum.php?id=456)\n" +
              "[456](/viewforum.php?id=456) - Internal link to fluxbb forum without link text\n" +
              "[Internal link to fluxbb user profile with link text](/profile.php?id=567)\n" +
              "[567](/profile.php?id=567) - Internal link to fluxbb user without link text\n" +
              "<img src=\"http://www.ruby-lang.org/images/header-ruby-logo.png\"/>\n" +
              "<img src=\"http://www.ruby-lang.org/images/header-ruby-logo.png\" alt=\"FluxBB allows alt text\"/>\n" +
              "<ul><li>Example list item 1.</li><li>Example list item 2.</li><li>Example list item 3.</li></ul>\n" +
              "<ol><li>Example list item 1.</li><li>Example list item 2.</li><li>Example list item 3.</li></ol>\n" +
              "<ol class=\"alpha\"><li>Example list item 1.</li><li>Example list item 2.</li><li>Example list item 3.</li></ol>\n" +
              "<ul><li>Example list items<li>with unclosed<li>list item tags</ul>\n" +
              ":) :| :( :D :O :laughing: :rage: :roll_eyes:\n" +
              ":)=) Smiley whitespace=) https://awkward.com?x=D :rage::mad::mad:"
            )
          end

          context "with bbcode examples which are best left in bbcode format" do
            let(:example_post_content) {
              "[u]Underlined text[/u]\n" +
              "[email]myname@example.com[/email] - email link without link text\n" +
              "[email=myname@example.com]Email link with link text[/email]" +
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
        end
      end

      context "with FLUXBB_RELATIVE_LINKS_BASE set" do
        before do
          stub_const(ImportScripts::FluxBB, "FLUXBB_RELATIVE_LINKS_BASE", "http://oldforum.com/") do
            importer = ImportScripts::FluxBB.new
            importer.instance_variable_set(:@bbcode_to_md, true)
            importer.import_posts
          end
        end

        context "with basic url tag relative links" do
          let(:example_post_content) {
            "[url=/about]Relative link[/url]\n" +
            "[url]/about[/url]"
          }
          it "rewrites relative links to absolute with the specified base" do
            expect(Post.last.raw).to eq(
              "[Relative link](http://oldforum.com/about)\n" +
              "[http://oldforum.com/about](http://oldforum.com/about)"
            )
          end
        end

        context "with FluxBB internal linking tags" do
          let(:example_post_content) {
            "[post=234]Internal link to fluxbb post with link text[/post]\n" +
            "[post]234[/post] - Internal link to fluxbb post without link text\n" +
            "[topic=345]Internal link to fluxbb topic with link text[/topic]\n" +
            "[topic]345[/topic] - Internal link to fluxbb topic without link text\n" +
            "[forum=456]Internal link to fluxbb forum with link text[/forum]\n" +
            "[forum]456[/forum] - Internal link to fluxbb forum without link text\n" +
            "[user=567]Internal link to fluxbb user profile with link text[/user]\n" +
            "[user]567[/user] - Internal link to fluxbb user without link text"
          }
          it "generates absolute links with the specified base" do
            expect(Post.last.raw).to eq(
              "[Internal link to fluxbb post with link text](http://oldforum.com/viewtopic.php?pid=234#p234)\n" +
              "[234](http://oldforum.com/viewtopic.php?pid=234#p234) - Internal link to fluxbb post without link text\n" +
              "[Internal link to fluxbb topic with link text](http://oldforum.com/viewtopic.php?id=345)\n" +
              "[345](http://oldforum.com/viewtopic.php?id=345) - Internal link to fluxbb topic without link text\n" +
              "[Internal link to fluxbb forum with link text](http://oldforum.com/viewforum.php?id=456)\n" +
              "[456](http://oldforum.com/viewforum.php?id=456) - Internal link to fluxbb forum without link text\n" +
              "[Internal link to fluxbb user profile with link text](http://oldforum.com/profile.php?id=567)\n" +
              "[567](http://oldforum.com/profile.php?id=567) - Internal link to fluxbb user without link text"
            )
          end
        end
      end
    end

    describe "#create_permalinks" do
      context "when we have imported a user" do
        fab!(:user) { Fabricate(:user) }
        before do
          user.custom_fields["import_id"] = 123
          user.save

          ImportScripts::FluxBB.new.create_permalinks
        end

        it "creates Permalink to redirect FluxBB-style forum URL" do
          expect(Permalink.find_by(url: "profile.php?id=123").external_url).to eq "/u/#{user.username}"
        end
      end

      context "when we have imported a post and parent topic" do
        fab!(:post) { Fabricate(:post) }
        let(:topic) { post.topic }
        before do
          post.custom_fields["import_id"] = 234
          post.save
          topic.custom_fields["import_id"] = 345
          topic.save

          ImportScripts::FluxBB.new.create_permalinks
        end

        it "creates Permalink to redirect FluxBB-style post URL" do
          expect(Permalink.find_by(url: "viewtopic.php?pid=234").post_id).to eq post.id
        end

        it "creates Permalink to redirect FluxBB-style topic URL" do
          expect(Permalink.find_by(url: "viewtopic.php?id=345").topic_id).to eq topic.id
        end
      end

      context "when we have imported a category (forum from fluxbb)" do
        fab!(:cat) { Fabricate(:category) }
        before do
          cat.custom_fields["import_id"] = 456
          cat.save

          ImportScripts::FluxBB.new.create_permalinks
        end

        it "creates Permalink to redirect FluxBB-style forum URL" do
          expect(Permalink.find_by(url: "viewforum.php?id=456").category_id).to eq cat.id
        end
      end
    end
  end
end
