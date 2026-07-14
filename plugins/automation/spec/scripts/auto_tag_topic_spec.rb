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
      fab!(:restricted_category, :category)
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

  context "with a topic" do
    context "when tags list is empty" do
      it "exits early with no error" do
        expect { automation.trigger!("topic" => topic) }.to_not raise_error
      end
    end

    context "when there are tags" do
      context "when closed_automatically is set" do
        before do
          automation.upsert_field!("tags", "tags", { value: %w[tag1 tag2] })
          automation.upsert_field!(
            "closed_automatically",
            "boolean",
            { value: true },
            target: "script",
          )
        end
        it "works" do
          automation.trigger!("topic" => topic, "status" => :automatically)

          expect(topic.reload.tags.pluck(:name)).to match_array(%w[tag1 tag2])
        end

        it "does not apply tags for manual closures" do
          automation.trigger!("topic" => topic, "status" => :manually)

          expect(topic.reload.tags.pluck(:name)).to be_empty
        end
      end
      context "when closed_manually is set" do
        before do
          automation.upsert_field!("tags", "tags", { value: %w[tag1 tag2] })
          automation.upsert_field!("closed_manually", "boolean", { value: true }, target: "script")
        end

        it "applies tags for manual closures" do
          automation.trigger!("topic" => topic, "status" => :manually)

          expect(topic.reload.tags.pluck(:name)).to match_array(%w[tag1 tag2])
        end

        it "does not apply tags for automatic closures" do
          automation.trigger!("topic" => topic, "status" => :automatically)

          expect(topic.reload.tags.pluck(:name)).to be_empty
        end
      end

      context "when both fields are set" do
        before do
          automation.upsert_field!("tags", "tags", { value: %w[tag1 tag2] })
          automation.upsert_field!(
            "closed_automatically",
            "boolean",
            { value: true },
            target: "script",
          )
          automation.upsert_field!("closed_manually", "boolean", { value: true }, target: "script")
        end

        it "applies tags for both closure types" do
          automation.trigger!("topic" => topic, "status" => :manually)
          expect(topic.reload.tags.pluck(:name)).to match_array(%w[tag1 tag2])

          topic.tags = []
          automation.trigger!("topic" => topic, "status" => :automatically)
          expect(topic.reload.tags.pluck(:name)).to match_array(%w[tag1 tag2])
        end
      end
    end
  end
end
