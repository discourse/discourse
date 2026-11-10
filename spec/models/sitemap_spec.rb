# frozen_string_literal: true

RSpec.describe Sitemap do
  describe ".regenerate_sitemaps" do
    fab!(:topic)

    it "always create the news and recent sitemaps" do
      described_class.regenerate_sitemaps

      sitemaps =
        Sitemap.where(
          name: [Sitemap::NEWS_SITEMAP_NAME, Sitemap::RECENT_SITEMAP_NAME],
          enabled: true,
        )

      expect(sitemaps.exists?).to eq(true)
    end

    it "bumps existing sitemaps last_posted_at attribute" do
      news =
        Sitemap.create!(
          name: Sitemap::NEWS_SITEMAP_NAME,
          enabled: true,
          last_posted_at: 10.days.ago,
        )

      described_class.regenerate_sitemaps

      expect(news.reload.last_posted_at).to eq_time(topic.updated_at)
    end

    it "creates the sitemap first page when there is a topic" do
      described_class.regenerate_sitemaps
      first_page = Sitemap.find_by(name: "1")

      expect(first_page.enabled).to eq(true)
    end

    it "only counts topics from unrestricted categories" do
      restricted_category = Fabricate(:category, read_restricted: true)
      topic.update!(category: restricted_category)
      Category.update_stats

      described_class.regenerate_sitemaps
      first_page = Sitemap.find_by(name: "1")

      expect(first_page).to be_nil
    end

    it "creates enough pages for every listed topic, including category definitions" do
      SiteSetting.sitemap_page_size = 1
      Fabricate(:category_with_definition)

      described_class.regenerate_sitemaps

      page_names =
        Sitemap
          .where(enabled: true)
          .where.not(name: [Sitemap::NEWS_SITEMAP_NAME, Sitemap::RECENT_SITEMAP_NAME])
          .pluck(:name)
      expect(page_names).to contain_exactly("1", "2")
    end

    it "sets each page's last_posted_at to the newest topic on that page" do
      SiteSetting.sitemap_page_size = 1
      newer_topic = Fabricate(:topic)
      topic.update_columns(updated_at: 2.days.ago)
      newer_topic.update_columns(updated_at: 1.day.ago)

      described_class.regenerate_sitemaps

      expect(Sitemap.find_by(name: "1").last_posted_at).to eq_time(topic.updated_at)
      expect(Sitemap.find_by(name: "2").last_posted_at).to eq_time(newer_topic.updated_at)
    end

    it "disable empty pages" do
      unused_page = Sitemap.touch("10")

      described_class.regenerate_sitemaps

      expect(unused_page.reload.enabled).to eq(false)
    end

    context "with a sitemap_topics_query modifier" do
      fab!(:excluded_topic, :topic)
      fab!(:last_topic, :topic)

      let(:plugin) { Plugin::Instance.new }
      let(:modifier) { Proc.new { |query| query.where.not(id: excluded_topic.id) } }

      before do
        SiteSetting.sitemap_page_size = 1
        DiscoursePluginRegistry.register_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      it "counts pages from the topics the modifier keeps, so pages and their contents agree" do
        described_class.regenerate_sitemaps

        page_names =
          Sitemap
            .where(enabled: true)
            .where.not(name: [Sitemap::NEWS_SITEMAP_NAME, Sitemap::RECENT_SITEMAP_NAME])
            .pluck(:name)
        expect(page_names).to contain_exactly("1", "2")

        expect(Sitemap.find_by(name: "1").topics.map(&:first)).to eq([topic.id])
        expect(Sitemap.find_by(name: "2").topics.map(&:first)).to eq([last_topic.id])
        expect(Sitemap.find_by(name: "2").last_posted_at).to eq_time(last_topic.updated_at)
      end
    end

    context "with a sitemap_topics_query modifier that joins several rows per topic" do
      fab!(:other_topic, :topic)

      let(:plugin) { Plugin::Instance.new }
      let(:modifier) do
        Proc.new do |query|
          query
            .joins("INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id")
            .where("tcf.name = 'sitemap_spec'")
            .distinct
        end
      end

      before do
        SiteSetting.sitemap_page_size = 1
        [topic, other_topic].each do |t|
          %w[a b].each { |v| TopicCustomField.create!(topic: t, name: "sitemap_spec", value: v) }
        end
        DiscoursePluginRegistry.register_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      it "counts each topic once" do
        described_class.regenerate_sitemaps

        page_names =
          Sitemap
            .where(enabled: true)
            .where.not(name: [Sitemap::NEWS_SITEMAP_NAME, Sitemap::RECENT_SITEMAP_NAME])
            .pluck(:name)
        expect(page_names).to contain_exactly("1", "2")

        expect(Sitemap.find_by(name: "1").topics.map(&:first)).to eq([topic.id])
        expect(Sitemap.find_by(name: "2").topics.map(&:first)).to eq([other_topic.id])
      end
    end
  end

  describe "#topics" do
    shared_examples "Excludes hidden and restricted topics" do
      it "doesn't include topics from restricted categories" do
        restricted_category = Fabricate(:category, read_restricted: true)
        Fabricate(:topic, category: restricted_category)

        topics_data = sitemap.topics

        expect(topics_data).to be_empty
      end

      it "doesn't include hidden topics" do
        Fabricate(:topic, visible: false)

        topics_data = sitemap.topics

        expect(topics_data).to be_empty
      end
    end

    shared_examples "Applies the sitemap_topics_query modifier" do
      fab!(:excluded_topic) { Fabricate(:topic, bumped_at: 1.minute.ago) }
      fab!(:kept_topic) { Fabricate(:topic, bumped_at: 1.minute.ago) }

      let(:plugin) { Plugin::Instance.new }
      let(:modifier) { Proc.new { |query| query.where.not(id: excluded_topic.id) } }

      before { DiscoursePluginRegistry.register_modifier(plugin, :sitemap_topics_query, &modifier) }

      after do
        DiscoursePluginRegistry.unregister_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      it "doesn't include topics the modifier drops" do
        topic_ids = sitemap.topics.map(&:first)

        expect(topic_ids).to contain_exactly(kept_topic.id)
      end
    end

    shared_examples "Lists each topic once with a distinct modifier" do
      fab!(:topic) { Fabricate(:topic, bumped_at: 1.minute.ago) }

      let(:plugin) { Plugin::Instance.new }
      let(:modifier) do
        Proc.new do |query|
          query
            .joins("INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id")
            .where("tcf.name = 'sitemap_spec'")
            .distinct
        end
      end

      before do
        %w[a b].each { |v| TopicCustomField.create!(topic: topic, name: "sitemap_spec", value: v) }
        DiscoursePluginRegistry.register_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(plugin, :sitemap_topics_query, &modifier)
      end

      it "lists a topic the modifier's join repeats once" do
        expect(sitemap.topics.map(&:first)).to eq([topic.id])
      end
    end

    context "when the sitemap corresponds to a page" do
      let(:sitemap) { described_class.new(enabled: true, last_posted_at: 1.minute.ago, name: "1") }

      it "returns an empty array if there no topics" do
        expect(sitemap.topics).to be_empty
      end

      it "returns all the necessary topic attributes to render a sitemap URL" do
        topic = Fabricate(:topic)

        topics_data = sitemap.topics.first

        expect(topics_data[0]).to eq(topic.id)
        expect(topics_data[1]).to eq(topic.slug)
        expect(topics_data[2]).to eq_time(topic.bumped_at)
        expect(topics_data[3]).to eq_time(topic.updated_at)
      end

      it "returns empty when the page is empty because the previous page is not full" do
        Fabricate(:topic)
        sitemap.name = "2"

        topics_data = sitemap.topics

        expect(topics_data).to be_empty
      end

      it "order topics by bumped_at asc" do
        topic_1 = Fabricate(:topic, bumped_at: 3.minutes.ago)
        topic_2 = Fabricate(:topic, bumped_at: 1.minute.ago)
        topic_3 = Fabricate(:topic, bumped_at: 20.minutes.ago)

        topic_ids = sitemap.topics.map { |td| td[0] }

        expect(topic_ids).to contain_exactly(topic_2.id, topic_1.id, topic_3.id)
      end

      it_behaves_like "Excludes hidden and restricted topics"
      it_behaves_like "Applies the sitemap_topics_query modifier"
      it_behaves_like "Lists each topic once with a distinct modifier"
    end

    context "with sitemap for recent topics" do
      let(:sitemap) do
        described_class.new(
          enabled: true,
          last_posted_at: 1.minute.ago,
          name: described_class::RECENT_SITEMAP_NAME,
        )
      end

      it "return topics that were bumped less than three days ago" do
        Fabricate(:topic, bumped_at: 4.days.ago)
        recent_topic = Fabricate(:topic, bumped_at: 2.days.ago, posts_count: 3)

        topics_data = sitemap.topics

        expect(topics_data.length).to eq(1)
        recent_topic_data = topics_data.first
        expect(recent_topic_data[0]).to eq(recent_topic.id)
        expect(recent_topic_data[1]).to eq(recent_topic.slug)
        expect(recent_topic_data[2]).to eq_time(recent_topic.bumped_at)
        expect(recent_topic_data[3]).to eq_time(recent_topic.updated_at)
        expect(recent_topic_data[4]).to eq(recent_topic.posts_count)
      end

      it_behaves_like "Excludes hidden and restricted topics"
      it_behaves_like "Applies the sitemap_topics_query modifier"
      it_behaves_like "Lists each topic once with a distinct modifier"
    end

    context "with news sitemap" do
      let(:sitemap) do
        described_class.new(
          enabled: true,
          last_posted_at: 1.minute.ago,
          name: described_class::NEWS_SITEMAP_NAME,
        )
      end

      it "returns topics that were bumped in the last 72 hours" do
        Fabricate(:topic, bumped_at: 73.hours.ago)
        recent_topic = Fabricate(:topic, bumped_at: 71.hours.ago)

        topics_data = sitemap.topics

        expect(topics_data.length).to eq(1)
        recent_topic_data = topics_data.first
        expect(recent_topic_data[0]).to eq(recent_topic.id)
        expect(recent_topic_data[1]).to eq(recent_topic.title)
        expect(recent_topic_data[2]).to eq(recent_topic.slug)
        expect(recent_topic_data[3]).to eq_time(recent_topic.updated_at)
      end

      it_behaves_like "Excludes hidden and restricted topics"
      it_behaves_like "Applies the sitemap_topics_query modifier"
      it_behaves_like "Lists each topic once with a distinct modifier"
    end
  end
end
