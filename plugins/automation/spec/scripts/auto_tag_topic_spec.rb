# frozen_string_literal: true

describe "AutoTagTopic" do
  fab!(:topic)
  fab!(:tag1) { Fabricate(:tag, name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, name: "tag2") }
  fab!(:tag3) { Fabricate(:tag, name: "tag3") }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scripts::AUTO_TAG_TOPIC) }

  context "when tags list is empty" do
    it "exits early with no error" do
      expect {
        post = create_post(topic: topic)
        automation.trigger!("post" => post)
      }.to_not raise_error
    end
  end

  context "when there are tags" do
    before { automation.upsert_field!("tags", "tags", { value: %w[tag1 tag2] }) }

    it "works" do
      post = create_post(topic: topic)
      automation.trigger!("post" => post)

      expect(topic.reload.tags.pluck(:name)).to match_array(%w[tag1 tag2])
    end

    it "does not remove existing tags" do
      post = create_post(topic: topic, tags: %w[totally])
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), ["tag3"])
      automation.trigger!("post" => post)

      expect(topic.reload.tags.pluck(:name).sort).to match_array(%w[tag1 tag2 tag3])
    end
  end

  context "with restricted tags" do
    fab!(:restricted_tag) { Fabricate(:tag, name: "restricted") }
    before { automation.upsert_field!("tags", "tags", { value: ["restricted"] }) }

    context "when group restricted tags" do
      fab!(:tag_group) do
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["restricted"])
      end

      it "works" do
        post = create_post(topic: topic)
        automation.trigger!("post" => post)
        expect(topic.reload.tags.pluck(:name).sort).to match_array(["restricted"])
      end
    end

    context "when category restricted tags" do
      fab!(:category)
      fab!(:restricted_category) { Fabricate(:category) }
      fab!(:category_tag) do
        CategoryTag.create!(category: restricted_category, tag: restricted_tag)
      end

      it "works" do
        topic.update!(category: restricted_category)
        post = create_post(topic: topic)
        automation.trigger!("post" => post)
        expect(topic.reload.tags.pluck(:name).sort).to match_array(["restricted"])
      end

      it "does not work when incorrect category" do
        topic.update!(category: category)
        post = create_post(topic: topic)
        automation.trigger!("post" => post)
        expect(topic.reload.tags.pluck(:name).sort).to match_array([])
      end
    end
  end
end
