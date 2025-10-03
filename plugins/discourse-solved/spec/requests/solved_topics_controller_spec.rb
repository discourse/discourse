# frozen_string_literal: true

describe DiscourseSolved::SolvedTopicsController do
  fab!(:user)
  fab!(:another_user) { Fabricate(:user) }
  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:answer_post) { Fabricate(:post, topic:, user:) }
  fab!(:solved_topic) { Fabricate(:solved_topic, topic:, answer_post:) }

  describe "#by_user" do
    context "when accessing with username" do
      it "returns solved posts for the specified user" do
        sign_in(admin)

        get "/solution/by_user.json", params: { username: user.username }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["user_solved_posts"]).to be_present
        expect(result["user_solved_posts"].length).to eq(1)
        expect(result["user_solved_posts"][0]["post_id"]).to eq(answer_post.id)
      end

      it "returns 404 for a non-existent user" do
        sign_in(admin)

        get "/solution/by_user.json", params: { username: "non-existent-user" }

        expect(response.status).to eq(404)
      end

      it "correctly handles the offset parameter" do
        sign_in(admin)

        get "/solution/by_user.json", params: { username: user.username, offset: 1 }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["user_solved_posts"]).to be_empty
      end

      it "correctly handles the limit parameter" do
        Fabricate(:solved_topic, answer_post: Fabricate(:post, user:))

        sign_in(admin)

        get "/solution/by_user.json", params: { username: user.username, limit: 1 }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["user_solved_posts"].length).to eq(1)
      end
    end

    context "when accessing without username" do
      it "returns 400 for the current user" do
        sign_in(user)

        get "/solution/by_user.json"

        expect(response.status).to eq(400)
      end

      it "returns 400 if not logged in" do
        get "/solution/by_user.json"

        expect(response.status).to eq(400)
      end
    end

    context "with visibility restrictions" do
      context "with private category solved topic" do
        fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
        fab!(:private_category) { Fabricate(:private_category, group:) }
        fab!(:private_topic) { Fabricate(:topic, category: private_category) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic) }
        fab!(:private_answer_post) { Fabricate(:post, topic: private_topic, user: user) }
        fab!(:private_solved_topic) do
          Fabricate(:solved_topic, topic: private_topic, answer_post: private_answer_post)
        end

        it "respects category permissions" do
          sign_in(another_user)

          get "/solution/by_user.json", params: { username: user.username }

          expect(response.status).to eq(200)
          result = response.parsed_body
          # admin sees both solutions
          expect(result["user_solved_posts"].length).to eq(1)

          sign_in(user)

          get "/solution/by_user.json", params: { username: user.username }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["user_solved_posts"].length).to eq(2)
        end
      end

      it "does not return PMs" do
        topic.update(archetype: Archetype.private_message, category: nil)

        sign_in(user)

        get "/solution/by_user.json", params: { username: user.username }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["user_solved_posts"]).to be_empty
      end
    end
  end
end
