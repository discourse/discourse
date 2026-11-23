# frozen_string_literal: true

RSpec.describe NewPostResultSerializer do
  it "includes the message and route_to if present" do
    result = NewPostResult.new(:custom, true)
    result.message = "hello :)"
    result.route_to = "/cool-route"

    serializer = described_class.new(result)
    expect(serializer.success).to eq(true)
    expect(serializer.message).to eq("hello :)")
    expect(serializer.route_to).to eq("/cool-route")
  end

  describe "post serializer options" do
    fab!(:post)
    let(:guardian) { post.user.guardian }
    let(:result) { NewPostResult.new(:create_post, true).tap { |result| result.post = post } }
    let(:serialized) { described_class.new(result, scope: guardian, root: false).as_json }

    it "preserves the nested post defaults and draft sequence" do
      draft_sequence = DraftSequence.next!(post.user, post.topic.draft_key)

      expect(serialized[:post][:id]).to eq(post.id)
      expect(serialized[:post][:raw]).to eq(post.raw)
      expect(serialized[:post][:draft_sequence]).to eq(draft_sequence)
      expect(serialized[:post][:yours]).to eq(true)
      expect(serialized[:post]).not_to have_key(:post)
    end

    context "with a plugin modifier" do
      let(:plugin) { Plugin::Instance.new }
      let(:modifier) { :new_post_result_post_serializer_options }
      let(:received_context) { [] }
      let(:modifier_block) do
        Proc.new do |options, post, guardian|
          received_context << [options.dup, post, guardian]
          options.merge(add_raw: false)
        end
      end

      before { DiscoursePluginRegistry.register_modifier(plugin, modifier, &modifier_block) }
      after { DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &modifier_block) }

      it "passes the post and guardian and applies the modified nested options" do
        expect(serialized[:post][:id]).to eq(post.id)
        expect(serialized[:post]).not_to have_key(:raw)
        expect(serialized[:post][:draft_sequence]).to eq(
          DraftSequence.current(post.user, post.topic.draft_key),
        )
        expect(received_context).to eq(
          [[{ scope: guardian, root: false, add_raw: true }, post, guardian]],
        )
      end

      it "ignores a disabled plugin" do
        plugin.stubs(:enabled?).returns(false)

        expect(serialized[:post][:raw]).to eq(post.raw)
        expect(received_context).to be_empty
      end

      it "omits the post and does not invoke the modifier for a queued result" do
        result.post = nil
        result.pending_count = 1

        expect(serialized).not_to have_key(:post)
        expect(serialized[:pending_count]).to eq(1)
        expect(serialized[:success]).to eq(true)
        expect(received_context).to be_empty
      end
    end
  end
end
