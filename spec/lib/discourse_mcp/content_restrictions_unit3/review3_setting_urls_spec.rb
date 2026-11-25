# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport
  include UploadsHelpers

  let(:denied_category) { Fabricate(:category, id: 111_730_100) }
  let(:denied_topic) { Fabricate(:topic, id: 111_730_101, category: denied_category) }
  let(:denied_post) { Fabricate(:post, id: 111_730_102, topic: denied_topic) }

  def review3_rows
    response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(response)
    payloads(response).map { |payload| payload.fetch("site_settings").sole }
  end

  def review3_rule(rule_kind)
    if rule_kind == "private_messages"
      McpContentRule.create!(rule_kind:, config: {})
    else
      forum_rule(denied_categories: [denied_category.id])
    end
  end

  def review3_urls_concealed(urls, rule_kind)
    original_default = SiteSetting.defaults[:tos_url]
    external = "https://external.example/terms"
    %i[value default].each do |field|
      urls.each do |url|
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, field == :default ? url : external)
        SiteSetting.tos_url = field == :value ? url : external
        review3_rows.each { |row| expect(row.fetch(field.to_s)).to eq(url) }
      end
    end
    review3_rule(rule_kind)
    aggregate_failures do
      %i[value default].each do |field|
        urls.each do |url|
          SiteSetting.defaults.set_regardless_of_locale(
            :tos_url,
            field == :default ? url : external,
          )
          SiteSetting.tos_url = field == :value ? url : external
          review3_rows.each do |row|
            expect(row).to include("value" => nil, "default" => nil, "redacted" => true),
            "LOCAL URL RETAINED in #{field}: #{url}"
          end
        end
      end
    end
  ensure
    SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
  end

  %w[forum_content private_messages].each do |rule_kind|
    %i[
      not_found_permalink
      post_localizations
      published_slug
      cast_topic_id
      static_pages
      login
      relative_paths
    ].each do |shape|
      it "[cr-u3] conceals #{shape} setting values and defaults under #{rule_kind}" do
        paths =
          case shape
          when :not_found_permalink
            Permalink.create!(url: "/t/legacy", topic: denied_topic)
            expect(Topic.find_by(slug: "legacy")).to be_nil
            ["/t/legacy"]
          when :post_localizations
            localization = Fabricate(:post_localization, id: 111_730_103, post: denied_post)
            expect(localization.id).not_to eq(denied_post.id)
            expect(PostLocalization.exists?(id: denied_post.id)).to eq(false)
            ["/post_localizations/#{denied_post.id}.json"]
          when :published_slug
            SiteSetting.enable_page_publishing = true
            page =
              Fabricate(
                :published_page,
                topic: denied_topic,
                slug: "review-three-seasonal",
                public: true,
              )
            ["/pub/#{page.slug}"]
          when :cast_topic_id
            path = "/t/#{denied_topic.id}anything"
            expect(Topic.find_by(id: "#{denied_topic.id}anything")).to eq(denied_topic)
            [path, "/t/456anything"]
          when :static_pages
            SiteSetting.guidelines_topic_id = denied_topic.id
            SiteSetting.tos_topic_id = denied_topic.id
            SiteSetting.privacy_topic_id = denied_topic.id
            %w[/faq /guidelines /rules /conduct /tos /privacy]
          when :login
            ["/login"]
          else
            %w[./login ../login]
          end
        urls =
          paths
            .flat_map do |local_path|
              [local_path, URI.join("#{Discourse.base_url}/", local_path).to_s]
            end
            .uniq
        review3_urls_concealed(urls, rule_kind)
      end
    end

    %i[current_hostname base_url cdn s3_cdn upload_store].each do |host|
      it "[cr-u3] conceals #{host} host setting values and defaults under #{rule_kind}" do
        base =
          case host
          when :current_hostname
            "https://#{Discourse.current_hostname}"
          when :base_url
            Discourse.stubs(:base_url).returns("https://review-three-site.example/forum")
            Discourse.base_url
          when :cdn
            set_cdn_url "https://review-three-cdn.example"
            GlobalSetting.cdn_url
          else
            setup_s3
            SiteSetting.s3_cdn_url = "https://review-three-uploads.example"
            host == :s3_cdn ? SiteSetting.s3_cdn_url : Discourse.store.absolute_base_url
          end
        urls = ["#{base}/garden-reference", "#{base.sub(/\Ahttps?:/, "")}/garden-reference"].uniq
        review3_urls_concealed(urls, rule_kind)
      end
    end

    it "[cr-u3] keeps external URL values and defaults under #{rule_kind}" do
      original_default = SiteSetting.defaults[:tos_url]
      review3_rule(rule_kind)
      ["https:", "http:", ""].each do |scheme|
        value = "#{scheme}//external.example/terms"
        default = "#{scheme}//other-external.example/terms"
        SiteSetting.tos_url = value
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
        review3_rows.each do |row|
          expect(row).to include("value" => value, "default" => default)
          expect(row["redacted"]).not_to eq(true)
        end
      end
    ensure
      SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
    end

    it "[cr-u3] keeps plain non-URL setting values and defaults under #{rule_kind}" do
      SiteSetting.title = "Seasonal garden forum"
      SiteSetting.max_tags_per_topic = 7
      review3_rule(rule_kind)
      response = rpc("discourse_list_site_settings", "names" => %w[title max_tags_per_topic])
      expect_usable(response)
      payloads(response).each do |payload|
        rows = payload.fetch("site_settings").index_by { |row| row.fetch("setting") }
        {
          "title" => SiteSetting.title,
          "max_tags_per_topic" => SiteSetting.max_tags_per_topic,
        }.each do |name, value|
          expect(rows.fetch(name)).to include(
            "value" => value.to_s,
            "default" => SiteSetting.defaults[name.to_sym].to_s,
          )
          expect(rows.fetch(name)["redacted"]).not_to eq(true)
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
