# frozen_string_literal: true

describe "Resolving an AI post reviewable on user deletion" do
  fab!(:current_user, :admin)

  before do
    enable_current_plugin
    sign_in(current_user)
  end

  let(:acted_reviewable) do
    ReviewableAiPost.needs_review!(
      target: Fabricate(:post, user: spammer),
      created_by: Discourse.system_user,
    )
  end

  include_examples "resolving a spammer's reviewables on user deletion"
end
