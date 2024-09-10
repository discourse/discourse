# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic, user: admin) }

  fab!(:post1) { Fabricate(:post, topic:, raw: "[poll]\n- A\n- B\n[/poll]") }
  fab!(:post2) { Fabricate(:post, topic:, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]") }
  fab!(:post3) { Fabricate(:post, topic:, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]") }
  fab!(:post4) { Fabricate(:post, topic:, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]") }
  fab!(:post5) { Fabricate(:post, topic:, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]") }
  fab!(:post6) { Fabricate(:post, topic:, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]") }
  fab!(:post7) { Fabricate(:post, topic:, raw: "[poll visibility=]\n- A\n- B\n[/poll]") }

  describe "#show" do
    context "when not logged in" do
      it "does not create N+1 queries to load polls" do
        queries = track_sql_queries { get "/t/#{topic.id}.json" }

        expect(response.status).to eq(200)

        poll_queries = queries.filter { |q| q =~ /FROM "?poll/ }
        # Expected queries:
        #
        # - load all polls
        # - load all options
        # - count votes for each poll
        # - count votes for each option
        expect(poll_queries.size).to eq(4)
      end
    end

    context "when logged in" do
      before { sign_in(admin) }

      it "does not create N+1 queries to load polls" do
        queries = track_sql_queries { get "/t/#{topic.id}.json" }

        poll_queries = queries.filter { |q| q =~ /FROM "?poll/ }

        # Expected queries:
        #
        # - all queries listed for "when not logged in"
        # - query to find out if the user has voted in each poll
        # - queries to get "serialized voters" (NOT TRACKED)
        expect(poll_queries.size).to eq(5)
      end
    end
  end
end
