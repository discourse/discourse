# frozen_string_literal: true

RSpec.describe AnonymousAction do
  fab!(:user)

  # Minimal stand-in for ActionDispatch::Cookies::CookieJar that the lib
  # interacts with via `cookies.signed[key]`/`cookies.delete(key, **opts)`.
  let(:cookies) do
    Class
      .new do
        def initialize
          @store = {}
        end

        def signed
          @store
        end

        def delete(key, **_opts)
          @store.delete(key)
        end
      end
      .new
  end

  before do
    AnonymousAction.register("anon_action_spec_test") do |handler_user, params|
      post = Post.find_by(id: params["post_id"])
      PostActionCreator.like(handler_user, post) if post
    end
  end

  after { AnonymousAction.unregister("anon_action_spec_test") }

  describe ".registered?" do
    it "returns true for registered types" do
      expect(AnonymousAction.registered?("anon_action_spec_test")).to eq(true)
    end

    it "returns false for unknown types" do
      expect(AnonymousAction.registered?("unknown_action")).to eq(false)
    end
  end

  describe ".set" do
    it "raises for an unregistered type" do
      expect { AnonymousAction.set(cookies, type: "ghost_action", params: {}) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe ".consume" do
    fab!(:post)

    it "runs the matching handler and clears the cookie" do
      cookies.signed[AnonymousAction::COOKIE] = {
        "type" => "anon_action_spec_test",
        "params" => {
          "post_id" => post.id,
        },
      }

      expect { AnonymousAction.consume(user, cookies) }.to change {
        PostAction.where(post: post, user: user).count
      }.by(1)

      expect(cookies.signed[AnonymousAction::COOKIE]).to be_nil
    end

    it "no-ops without a cookie" do
      expect { AnonymousAction.consume(user, cookies) }.not_to raise_error
    end

    it "ignores unknown handler types and clears the cookie" do
      cookies.signed[AnonymousAction::COOKIE] = { "type" => "ghost", "params" => {} }

      expect { AnonymousAction.consume(user, cookies) }.not_to raise_error
      expect(cookies.signed[AnonymousAction::COOKIE]).to be_nil
    end

    it "swallows handler exceptions" do
      AnonymousAction.register("anon_action_spec_boom") { |_, _| raise "kaboom" }
      cookies.signed[AnonymousAction::COOKIE] = {
        "type" => "anon_action_spec_boom",
        "params" => {
        },
      }

      expect { AnonymousAction.consume(user, cookies) }.not_to raise_error
      expect(cookies.signed[AnonymousAction::COOKIE]).to be_nil
    ensure
      AnonymousAction.unregister("anon_action_spec_boom")
    end
  end
end
