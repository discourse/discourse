# frozen_string_literal: true

RSpec.describe HashtagRemapper do
  def remap(type:, record:, old_ref:, new_ref:, rewritten: Set.new)
    described_class.new(type:, record_id: record.id, old_ref:, new_ref:, rewritten:).remap!
  end

  def remap_tag(tag, old_ref, rewritten: Set.new)
    remap(type: "tag", record: tag, old_ref:, new_ref: tag.name, rewritten:)
  end

  describe "posts" do
    it "rewrites a bare reference and re-cooks" do
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support for details.")

      tag.update!(name: "help")
      remap_tag(tag, "support")

      expect(post.reload.raw).to eq("See #help for details.")
      expect(post.cooked).to include(%{data-type="tag"}, %{data-id="#{tag.id}"})
    end

    it "rewrites the type-suffixed form and keeps the suffix" do
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support::tag for details.")

      tag.update!(name: "help")
      remap_tag(tag, "support")

      expect(post.reload.raw).to eq("See #help::tag for details.")
    end

    it "leaves a longer reference belonging to another tag" do
      Fabricate(:tag, name: "node.js")
      tag = Fabricate(:tag, name: "node")
      post = create_post(raw: "I use #node.js daily and #node rarely.")

      tag.update!(name: "nodejs")
      remap_tag(tag, "node")

      expect(post.reload.raw).to eq("I use #node.js daily and #nodejs rarely.")
    end

    it "leaves a non-ascii neighbour alone" do
      Fabricate(:tag, name: "café")
      tag = Fabricate(:tag, name: "caf")
      post = create_post(raw: "One #caf and two #café here.")

      tag.update!(name: "coffee")
      remap_tag(tag, "caf")

      expect(post.reload.raw).to eq("One #coffee and two #café here.")
    end

    it "leaves references the markdown pipeline does not cook" do
      tag = Fabricate(:tag, name: "support")
      raw = <<~MD
        Live #support here.

        ```
        fence #support
        ```

        Inline `#support` and https://example.com/?tab=#support
      MD
      post = create_post(raw:)

      tag.update!(name: "help")
      remap_tag(tag, "support")

      expect(post.reload.raw).to eq(raw.sub("Live #support", "Live #help").rstrip)
    end

    it "only rewrites the suffixed form when a category owns the bare reference" do
      Fabricate(:category, slug: "clash")
      tag = Fabricate(:tag, name: "clash")
      post = create_post(raw: "Bare #clash and explicit #clash::tag.")

      expect(post.cooked).to include(%{data-type="category"})

      tag.update!(name: "clash-tag")
      remap_tag(tag, "clash")

      expect(post.reload.raw).to eq("Bare #clash and explicit #clash-tag::tag.")
    end

    it "rewrites the bare reference when this post cooked it as the tag" do
      category = Fabricate(:category, slug: "secret")
      category.update!(read_restricted: true)
      tag = Fabricate(:tag, name: "secret")
      post = create_post(raw: "Bare #secret here.")

      expect(post.cooked).to include(%{data-type="tag"})

      tag.update!(name: "secret-tag")
      remap_tag(tag, "secret")

      expect(post.reload.raw).to eq("Bare #secret-tag here.")
    end

    it "uses the suffixed form when the new reference would resolve elsewhere" do
      Fabricate(:category, slug: "help", name: "Help")
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support here.")

      expect(post.cooked).to include(%{data-type="tag"})

      tag.update!(name: "help")
      remap_tag(tag, "support")

      post.reload
      expect(post.raw).to eq("See #help::tag here.")
      expect(post.cooked).to include(%{data-type="tag"}, %{data-id="#{tag.id}"})
    end

    it "remaps a synonym by its own name" do
      target = Fabricate(:tag, name: "main")
      synonym = Fabricate(:tag, name: "syn", target_tag: target)
      post = create_post(raw: "See #syn and #main.")

      synonym.update!(name: "synonym")
      remap_tag(synonym, "syn")

      expect(post.reload.raw).to eq("See #synonym and #main.")
    end

    it "does not revise, bump or reattribute the post" do
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support for details.")
      editor = post.last_editor_id
      bumped = post.topic.bumped_at

      tag.update!(name: "help")
      remap_tag(tag, "support")

      post.reload
      expect(post.raw).to eq("See #help for details.")
      expect(post.version).to eq(1)
      expect(post.last_editor_id).to eq(editor)
      expect(PostRevision.where(post_id: post.id).count).to eq(0)
      expect(post.topic.reload.bumped_at).to eq_time(bumped)
    end

    it "rewrites a post that no longer passes validation" do
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support for details.")

      tag.update!(name: "help")
      SiteSetting.max_post_length = 5
      remap_tag(tag, "support")

      expect(post.reload.raw).to eq("See #help for details.")
    end

    it "re-runs post processing so the cooked keeps its lightboxes and oneboxes" do
      tag = Fabricate(:tag, name: "support")
      post = create_post(raw: "See #support for details.")

      tag.update!(name: "help")

      expect_enqueued_with(job: :process_post, args: { post_id: post.id }) do
        remap_tag(tag, "support")
      end
    end

    it "keeps going when one record fails" do
      tag = Fabricate(:tag, name: "support")
      first = create_post(raw: "First #support here.")
      second = create_post(raw: "Second #support here.")

      tag.update!(name: "help")
      Post.any_instance.stubs(:save!).raises(StandardError.new("boom")).then.returns(true)
      Discourse.expects(:warn_exception).once

      counts = remap_tag(tag, "support")

      expect(counts["post"][:scanned]).to eq(2)
      expect(counts["post"][:failed]).to eq(1)
    end
  end

  describe "references that never belonged to this record" do
    it "leaves prose alone even after the content is rebaked" do
      post = nil
      freeze_time(2.days.ago) { post = create_post(raw: "Ticket #support was closed.") }

      expect(post.cooked).not_to include("hashtag-cooked")

      tag = Fabricate(:tag, name: "support")
      tag.update!(name: "help")
      post.rebake!

      remap_tag(tag, "support")

      expect(post.reload.raw).to eq("Ticket #support was closed.")
    end

    it "leaves content authored after the rename alone" do
      tag = Fabricate(:tag, name: "support")
      tag.update!(name: "help")

      post = create_post(raw: "Ticket #support was closed.")

      remap_tag(tag, "support")

      expect(post.reload.raw).to eq("Ticket #support was closed.")
    end

    it "still rewrites a reference this run orphaned itself" do
      parent = Fabricate(:category, slug: "support")
      child = Fabricate(:category, slug: "bucks", parent_category: parent)
      post = create_post(raw: "See #support and #support:bucks.")

      parent.update!(slug: "help")
      rewritten = Set.new

      remap(type: "category", record: parent, old_ref: "support", new_ref: "help", rewritten:)
      remap(
        type: "category",
        record: child,
        old_ref: "support:bucks",
        new_ref: "help:bucks",
        rewritten:,
      )

      expect(post.reload.raw).to eq("See #help and #help:bucks.")
    end
  end

  describe "the other content stores" do
    fab!(:tag) { Fabricate(:tag, name: "support") }

    def rename_and_remap
      tag.update!(name: "help")
      remap_tag(tag, "support")
    end

    it "rewrites a user bio" do
      profile = Fabricate(:user).user_profile
      profile.update!(bio_raw: "I follow #support closely.")

      rename_and_remap

      profile.reload
      expect(profile.bio_raw).to eq("I follow #help closely.")
      expect(profile.bio_cooked).to include(%{data-id="#{tag.id}"})
    end

    it "rewrites a group bio" do
      group = Fabricate(:group, bio_raw: "We own #support.")

      rename_and_remap

      expect(group.reload.bio_raw).to eq("We own #help.")
    end

    it "rewrites a tag description" do
      other = Fabricate(:tag, name: "other", description: "See also #support.")

      rename_and_remap

      other.reload
      expect(other.description).to eq("See also #help.")
      expect(other.description_cooked).to include(%{data-id="#{tag.id}"})
    end

    it "rewrites a post localization" do
      post = create_post(raw: "See #support.")
      localization =
        Fabricate(
          :post_localization,
          post:,
          locale: "fr",
          raw: "Voir #support.",
          cooked: PrettyText.cook("Voir #support."),
        )

      expect_enqueued_with(
        job: :process_localized_cooked,
        args: {
          post_localization_id: localization.id,
        },
      ) { rename_and_remap }

      localization.reload
      expect(localization.raw).to eq("Voir #help.")
      expect(localization.cooked).to include(%{data-id="#{tag.id}"})
    end

    it "rewrites a tag localization description" do
      other = Fabricate(:tag, name: "other")
      localization =
        Fabricate(:tag_localization, tag: other, locale: "fr", description: "Voir #support.")

      rename_and_remap

      expect(localization.reload.description).to eq("Voir #help.")
    end

    it "rewrites only the suffixed form in a store that does not keep cooked" do
      category = Fabricate(:category)
      localization =
        Fabricate(
          :category_localization,
          category:,
          locale: "fr",
          description: "Voir #support et #support::tag.",
        )

      rename_and_remap

      expect(localization.reload.description).to eq("Voir #support et #help::tag.")
    end
  end
end
