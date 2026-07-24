# frozen_string_literal: true

RSpec.describe DiscourseSolved::AnswerController do
  fab!(:user)
  fab!(:staff_user, :admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:p) { Fabricate(:post, topic: topic) }
  fab!(:solution_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    category.save_custom_fields

    # Give permission to accept solutions
    user.update!(trust_level: 1)

    # Make user the topic creator so they can accept answers
    topic.update!(user_id: user.id)
  end

  describe "#accept" do
    context "with default rate limiting" do
      it "applies rate limits to regular users" do
        sign_in(user)

        # Should be rate limited
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429)
      end

      it "does not apply rate limits to staff" do
        sign_in(staff_user)

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
      end
    end

    context "with plugin modifier" do
      it "allows plugins to bypass rate limiting" do
        sign_in(user)
        # Create a plugin instance and register a modifier
        plugin_instance = Plugin::Instance.new
        modifier_block = Proc.new { |_, _| false }
        plugin_instance.register_modifier(
          :solved_answers_controller_run_rate_limiter,
          &modifier_block
        )

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
        post "/solution/unaccept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Unregister the modifier using DiscoursePluginRegistry
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :solved_answers_controller_run_rate_limiter,
          &modifier_block
        )
      end
    end

    it "returns single accepted answer in an array" do
      sign_in(user)

      post "/solution/accept.json", params: { id: solution_post.id }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result[0]["id"]).to eq(solution_post.id)
    end

    context "with multiple solutions enabled" do
      fab!(:solution_post2) { Fabricate(:post, topic: topic) }

      before { SiteSetting.solved_allow_multiple_solutions = true }

      it "returns an array with multiple accepted answers" do
        sign_in(user)

        post "/solution/accept.json", params: { id: solution_post.id }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0]["id"]).to eq(solution_post.id)

        post "/solution/accept.json", params: { id: solution_post2.id }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0]["id"]).to eq(solution_post.id)
        expect(result[1]["id"]).to eq(solution_post2.id)
      end
    end
  end

  describe "#unaccept" do
    before do
      # Setup an accepted solution
      sign_in(user)
      post "/solution/accept.json", params: { id: solution_post.id }
      expect(response.status).to eq(200)
      sign_out
    end

    it "applies rate limits to regular users" do
      sign_in(user)

      # Should be rate limited
      RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
      post "/solution/unaccept.json", params: { id: solution_post.id }
      expect(response.status).to eq(429)
    end

    it "returns an empty array of accepted answers after unaccepting" do
      sign_in(user)

      post "/solution/unaccept.json", params: { id: solution_post.id }

      expect(response.status).to eq(200)
      result = response.parsed_body
      expect(result).to be_nil
    end

    context "with multiple solutions enabled" do
      fab!(:solution_post2) { Fabricate(:post, topic: topic) }

      before do
        SiteSetting.solved_allow_multiple_solutions = true
        sign_in(user)
        post "/solution/accept.json", params: { id: solution_post2.id }
        sign_out
      end

      it "returns remaining accepted answers as an array" do
        sign_in(user)

        post "/solution/unaccept.json", params: { id: solution_post.id }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0]["id"]).to eq(solution_post2.id)
      end
    end
  end
end
