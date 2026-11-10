# frozen_string_literal: true

RSpec.describe "blog:refresh_articles" do
  include_context "with blog editorial setup"

  fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:first_post) { Fabricate(:post, topic:, user: writer) }

  before do
    if !Rake::Task.task_defined?("blog:refresh_articles")
      Rake.load_rakefile(File.expand_path("../../lib/tasks/articles.rake", __dir__))
    end
    publish_blog_draft(publication, acting_user)
  end

  it "copies the rebaked discussion post into the published article" do
    publication.discussion_topic.first_post.update_columns(cooked: "<p>Rebaked after import.</p>")
    draft = Blog::Publication.for_topic(Fabricate(:topic, category: drafts, user: writer))
    draft.save!

    expect { invoke_rake_task("blog:refresh_articles") }.to output(
      "Refreshed 1 published article.\n",
    ).to_stdout
    expect(publication.reload.article.cooked).to eq("<p>Rebaked after import.</p>")
    expect(draft.reload.cooked).to be_nil
  end
end
