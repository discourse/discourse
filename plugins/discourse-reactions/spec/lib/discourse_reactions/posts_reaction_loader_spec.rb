# frozen_string_literal: true

RSpec.describe DiscourseReactions::PostsReactionLoader do
  fab!(:user)
  fab!(:post)

  before { SiteSetting.discourse_reactions_enabled = true }

  it "preloads reactions through the namespaced helper when data was not preloaded" do
    fake_topic_view =
      Struct
        .new(:posts, :guardian) do
          def preloaded_post_data(_key)
            nil
          end
        end
        .new([post], Struct.new(:user).new(user))

    loader =
      Class
        .new do
          include DiscourseReactions::PostsReactionLoader

          attr_reader :object

          def initialize(object)
            @object = object
          end
        end
        .new(fake_topic_view)

    allow(DiscourseReactions::ReactionsSerializerHelpers).to receive(:preload_post_reactions)

    loader.posts_with_reactions

    expect(DiscourseReactions::ReactionsSerializerHelpers).to have_received(
      :preload_post_reactions,
    ).with([post], user)
  end
end
