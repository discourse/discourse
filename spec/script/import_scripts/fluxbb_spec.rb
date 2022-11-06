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

        let(:example_post_content) {
          "My post [b]content[/b]"
        }

        it "converts bbcode to markdown in the resulting Post" do
          expect(Post.last.raw).to eq("My post **content**")
        end
      end
    end
  end
end
