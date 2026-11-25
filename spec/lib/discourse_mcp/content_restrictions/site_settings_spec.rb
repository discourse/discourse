# frozen_string_literal: true

require_relative "read_tool_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server do
  include McpContentReadHelpers

  describe "ListSiteSettings" do
    it "conceals personal-message URLs with only private_messages active and conceals public URLs" do
      message =
        Fabricate(
          :private_message_topic,
          id: 92_300_001,
          user: admin,
          title: "cru3 private legal destination",
        )
      Fabricate(:post, topic: message, user: admin)
      public_topic = Fabricate(:topic, user: admin)
      Fabricate(:post, topic: public_topic, user: admin)
      SiteSetting.tos_url = message.url
      baseline = rpc("discourse_list_site_settings", "names" => ["tos_url"])
      expect_usable(baseline)
      expect(payloads(baseline).first.fetch("site_settings").first.fetch("value")).to eq(
        message.url,
      )
      McpContentRule.create!(rule_kind: "private_messages", config: {})
      expect(McpContentRule.pluck(:rule_kind)).to eq(["private_messages"])

      response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
      expect_usable(response)
      SiteSetting.tos_url = public_topic.url
      public_response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
      expect_usable(public_response)

      aggregate_failures do
        expect_absent(
          response,
          [message.relative_url, message.slug, message.id],
          "ListSiteSettings PM URL",
        )
        payloads(public_response).each do |payload|
          expect(payload.fetch("site_settings")).to include(
            a_hash_including(
              "setting" => "tos_url",
              "value" => nil,
              "default" => nil,
              "redacted" => true,
            ),
          )
        end
      end
    end

    describe "with local routes" do
      def setting_url_response(url)
        SiteSetting.tos_url = url
        rpc("discourse_list_site_settings", "names" => ["tos_url"]).tap do |response|
          expect_usable(response)
        end
      end

      def expect_setting_url(response, url)
        payloads(response).each do |payload|
          expect(payload.fetch("site_settings")).to include(
            a_hash_including("setting" => "tos_url", "value" => url),
          )
        end
      end

      def local_paths(family, topic:, post:, category:, tag:)
        case family
        when "topic and post"
          [
            "/p/#{post.id}",
            "/t/#{topic.slug}/#{topic.id}/#{post.post_number}",
            "/t/#{topic.id}/#{post.post_number}",
            "/t/#{topic.id}",
          ]
        when "category"
          ["/c/#{category.slug}/#{category.id}", "/c/#{category.id}"]
        when "tag"
          ["/tag/#{tag.name}", "/tags/#{tag.name}"]
        end
      end

      shared_examples "local setting URLs" do |family, rule_kind|
        it "conceals absolute and relative #{family} routes under #{rule_kind}" do
          denied_category = Fabricate(:category, id: 91_310_001)
          allowed_category = Fabricate(:category, id: 91_310_002)
          denied_tag = Fabricate(:tag, name: "cru3-route-denied")
          allowed_tag = Fabricate(:tag, name: "cru3-route-allowed")
          restricted_topic =
            if rule_kind == "private_messages"
              Fabricate(:private_message_topic, id: 92_310_002, user: admin)
            else
              Fabricate(:topic, id: 92_310_002, user: admin, category: denied_category)
            end
          Fabricate(:post, topic: restricted_topic, user: admin)
          restricted_post = Fabricate(:post, id: 93_310_002, topic: restricted_topic, user: admin)
          restricted_topic.tags << denied_tag
          allowed_topic = Fabricate(:topic, user: admin, category: allowed_category)
          Fabricate(:post, topic: allowed_topic, user: admin)
          allowed_post = Fabricate(:post, topic: allowed_topic, user: admin)
          allowed_topic.tags << allowed_tag
          restricted_paths =
            local_paths(
              family,
              topic: restricted_topic,
              post: restricted_post,
              category: denied_category,
              tag: denied_tag,
            )
          allowed_paths =
            local_paths(
              family,
              topic: allowed_topic,
              post: allowed_post,
              category: allowed_category,
              tag: allowed_tag,
            )
          urls =
            restricted_paths
              .zip(allowed_paths)
              .flat_map do |restricted_path, allowed_path|
                [
                  [restricted_path, allowed_path],
                  [
                    "#{Discourse.base_url}#{restricted_path}",
                    "#{Discourse.base_url}#{allowed_path}",
                  ],
                ]
              end
          urls.flatten.each { |url| expect_setting_url(setting_url_response(url), url) }
          if rule_kind == "private_messages"
            McpContentRule.create!(rule_kind:, config: {})
          else
            forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
          end
          expect(McpContentRule.pluck(:rule_kind)).to eq([rule_kind])
          forbidden =
            case family
            when "topic and post"
              [restricted_topic.id, restricted_post.id, restricted_topic.slug]
            when "category"
              [denied_category.id, denied_category.slug]
            when "tag"
              [denied_tag.name]
            end

          aggregate_failures do
            urls.each do |restricted_url, allowed_url|
              response = setting_url_response(restricted_url)
              expect_absent(
                response,
                [restricted_url, *forbidden],
                "#{rule_kind} #{restricted_url}",
              )
              payloads(setting_url_response(allowed_url)).each do |payload|
                expect(payload.fetch("site_settings").sole).to include(
                  "value" => nil,
                  "default" => nil,
                  "redacted" => true,
                ),
                "local URL retained: #{allowed_url}"
              end
            end
          end
        end
      end

      include_examples "local setting URLs", "topic and post", "forum_content"
      include_examples "local setting URLs", "category", "forum_content"
      include_examples "local setting URLs", "tag", "forum_content"
      include_examples "local setting URLs", "topic and post", "private_messages"
    end

    describe "with routes that resolve to content" do
      let(:denied_category) { Fabricate(:category, id: 94_510_001) }
      let(:allowed_category) { Fabricate(:category, id: 94_510_002) }
      let(:denied_tag) { Fabricate(:tag, id: 97_510_001, name: "cru3-r3-denied") }
      let(:allowed_tag) { Fabricate(:tag, id: 97_510_002, name: "cru3-r3-allowed") }
      let(:allowed_topic) do
        Fabricate(:topic, id: 95_510_002, user: admin, category: allowed_category)
      end
      let(:allowed_post) { Fabricate(:post, id: 96_510_002, topic: allowed_topic, user: admin) }

      def setting_url_response(url)
        SiteSetting.tos_url = url
        rpc("discourse_list_site_settings", "names" => ["tos_url"]).tap do |result|
          expect_usable(result)
        end
      end

      def expect_kept_url(url)
        payloads(setting_url_response(url)).each do |payload|
          expect(payload.fetch("site_settings")).to include(
            a_hash_including("setting" => "tos_url", "value" => url),
          )
        end
      end

      def expect_concealed_paths(path_pairs)
        url_pairs =
          path_pairs.flat_map do |restricted_path, allowed_path|
            [
              [restricted_path, allowed_path],
              ["#{Discourse.base_url}#{restricted_path}", "#{Discourse.base_url}#{allowed_path}"],
            ]
          end
        url_pairs.flatten.each { |url| expect_kept_url(url) }
        yield

        aggregate_failures do
          url_pairs.each do |restricted_url, allowed_url|
            [restricted_url, allowed_url].each do |url|
              result = setting_url_response(url)
              payloads(result).each do |payload|
                expect(payload.fetch("site_settings")).to include(
                  a_hash_including(
                    "setting" => "tos_url",
                    "value" => nil,
                    "default" => nil,
                    "redacted" => true,
                  ),
                ),
                "local URL retained: #{url} in #{payload.inspect}"
              end
              expect_absent(result, [url], url)
            end
          end
        end
      end

      def restrict_urls(rule_kind)
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
        end
        expect(McpContentRule.pluck(:rule_kind)).to eq([rule_kind])
      end

      def restricted_topic(rule_kind)
        if rule_kind == "private_messages"
          Fabricate(:private_message_topic, id: 95_510_001, user: admin)
        else
          Fabricate(:topic, id: 95_510_001, user: admin, category: denied_category)
        end
      end

      def redirect_destination(path, status:)
        client = ActionDispatch::Integration::Session.new(Rails.application)
        client.host! Discourse.current_hostname
        client.get(path)
        expect(client.response.status).to eq(status), client.response.body
        URI(client.response.headers.fetch("Location")).path
      end

      shared_examples "topic_id setting URLs" do |shape, rule_kind|
        it "conceals absolute and relative #{shape} URLs under #{rule_kind}" do
          SiteSetting.nested_replies_enabled = true if shape == "nested_topics"
          topic = restricted_topic(rule_kind)
          Fabricate(:post, topic:, user: admin)
          Fabricate(:post, topic: allowed_topic, user: admin)
          post = Fabricate(:post, id: 96_510_001, topic:, user: admin)
          paths =
            [topic, allowed_topic].map do |record|
              case shape
              when "raw"
                "/raw/#{record.id}"
              when "posts/by_number"
                "/posts/by_number/#{record.id}/#{post.post_number}"
              when "nested_topics"
                "/n/#{record.slug}/#{record.id}"
              end
            end
          allowed_post
          expect(post.id).not_to eq(topic.id)
          expect(post.post_number).to eq(2)
          expect(allowed_post.post_number).to eq(post.post_number)
          expect(Post.exists?(id: topic.id)).to eq(false)
          paths
            .zip([topic, allowed_topic])
            .each do |path, record|
              expect(Discourse.route_for(path)).to include(topic_id: record.id.to_s)
            end

          expect_concealed_paths([paths]) { restrict_urls(rule_kind) }
        end
      end

      %w[forum_content private_messages].each do |rule_kind|
        %w[raw posts/by_number nested_topics].each do |shape|
          include_examples "topic_id setting URLs", shape, rule_kind
        end
      end

      shared_examples "category action setting URLs" do |action|
        it "conceals absolute and relative category #{action} URLs under forum_content" do
          paths =
            [denied_category, allowed_category].map do |category|
              key = action == "show" ? category.id : category.slug
              path = "/c/#{key}/#{action}"
              parameter = action == "show" ? :id : :category_slug
              expect(Discourse.route_for(path)).to include(
                :controller => "categories",
                parameter => key.to_s,
              )
              path
            end

          expect_concealed_paths([paths]) { restrict_urls("forum_content") }
        end
      end

      include_examples "category action setting URLs", "show"
      include_examples "category action setting URLs", "edit"
      include_examples "category action setting URLs", "find_by_slug"

      it "conceals absolute and relative renamed tag id redirect URLs under forum_content" do
        retired_slug = denied_tag.slug_for_url
        denied_tag.update!(name: "cru3-r3-renamed", slug: "cru3-r3-renamed")
        expect(Tag.find_by_name(retired_slug)).to be_nil
        expect(Tag.find_by(slug: retired_slug)).to be_nil
        paths = [
          "/tags/#{retired_slug}/#{denied_tag.id}",
          "/tags/retired-allowed/#{allowed_tag.id}",
        ]
        paths
          .zip([denied_tag, allowed_tag])
          .each do |path, tag|
            destination = redirect_destination(path, status: 301)
            expect(Discourse.route_for("#{destination}.json")).to include(
              controller: "tags",
              tag_id: tag.id.to_s,
            )
          end

        expect_concealed_paths([paths]) { restrict_urls("forum_content") }
      end

      it "conceals absolute and relative numeric tag name fallback URLs under forum_content" do
        denied_tag.update!(name: "98510001", slug: "98510001")
        allowed_tag.update!(name: "98510002", slug: "98510002")
        paths =
          [denied_tag, allowed_tag].map do |tag|
            expect(Tag.find_by(id: tag.name)).to be_nil
            expect(Tag.find_by_name(tag.name)).to eq(tag)
            path = "/tag/#{tag.name}.json"
            expect(Discourse.route_for(path)).to include(controller: "tags", tag_id: tag.name)
            path
          end

        expect_concealed_paths([paths]) { restrict_urls("forum_content") }
      end

      it "conceals absolute and relative redirect route URLs by their restricted destination under forum_content" do
        paths =
          [denied_category, allowed_category].map do |category|
            path = "/category/#{category.slug}/#{category.id}"
            expect(Discourse.route_for(path)).to include(
              controller: "categories",
              action: "redirect",
            )
            destination = redirect_destination(path, status: 302)
            expect(
              Category.find_by_slug_path_with_id(
                Discourse.route_for(destination).fetch(:category_slug_path_with_id),
              ),
            ).to eq(category)
            path
          end

        expect_concealed_paths([paths]) { restrict_urls("forum_content") }
      end

      shared_examples "permalink setting URLs" do |rule_kind|
        it "conceals absolute and relative permalink URLs by their restricted target under #{rule_kind}" do
          topic = restricted_topic(rule_kind)
          post = Fabricate(:post, id: 96_510_001, topic:, user: admin)
          targets = [[topic, allowed_topic], [post, allowed_post]]
          targets += [
            [denied_category, allowed_category],
            [denied_tag, allowed_tag],
          ] if rule_kind == "forum_content"
          paths =
            targets.each_with_index.map do |records, index|
              records.each_with_index.map do |record, side|
                association = record.class.name.underscore.to_sym
                permalink =
                  Permalink.create!(
                    :url => "cru3-r3-archive/#{index}/#{side}",
                    association => record,
                  )
                path = "/#{permalink.url}"
                expect(Discourse.route_for(path)).to include(
                  controller: "permalinks",
                  action: "show",
                )
                expect(Permalink.find_by_url(path).target_url).to eq(record.relative_url)
                expect(admin.guardian.can_see_permalink_target?(permalink)).to eq(true)
                path
              end
            end

          expect_concealed_paths(paths) { restrict_urls(rule_kind) }
        end
      end

      shared_examples "unrecognized setting URLs" do |rule_kind|
        it "conceals absolute and relative unrecognized local URLs under #{rule_kind} and recognized allowed URLs" do
          unrecognized_path = "/cru3-r3-browser-only/opaque-reference"
          recognized_path = "/t/#{allowed_topic.slug}/#{allowed_topic.id}"
          expect(Discourse.route_for(unrecognized_path)).to be_nil
          expect(Permalink.find_by_url(unrecognized_path)).to be_nil
          expect(Discourse.route_for(recognized_path)).to include(
            controller: "topics",
            topic_id: allowed_topic.id.to_s,
          )

          expect_concealed_paths([[unrecognized_path, recognized_path]]) do
            restrict_urls(rule_kind)
          end
        end
      end

      include_examples "permalink setting URLs", "forum_content"
      include_examples "permalink setting URLs", "private_messages"
      include_examples "unrecognized setting URLs", "forum_content"
      include_examples "unrecognized setting URLs", "private_messages"
    end

    describe "with permalinks and external identifiers" do
      let(:denied_category) { Fabricate(:category, id: 102_620_001) }
      let(:allowed_category) { Fabricate(:category, id: 102_620_002) }
      let(:denied_topic) do
        Fabricate(
          :topic,
          id: 103_620_001,
          category: denied_category,
          external_id: "review-two-denied",
        )
      end
      let(:allowed_topic) do
        Fabricate(
          :topic,
          id: 103_620_002,
          category: allowed_category,
          external_id: "review-two-allowed",
        )
      end

      def tos_url_settings(url)
        SiteSetting.tos_url = url
        response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(response)
        payloads(response).map { |payload| payload.fetch("site_settings").sole }
      end

      def expect_url_kept(url)
        tos_url_settings(url).each do |setting|
          expect(setting).to include("value" => url), "allowed URL redacted: #{url}"
          expect(setting["redacted"]).not_to eq(true)
        end
      end

      def expect_url_hidden(url)
        tos_url_settings(url).each do |setting|
          expect(setting).to include("value" => nil, "default" => nil, "redacted" => true),
          "restricted URL retained: #{url}"
        end
      end

      def get_json(path)
        client = ActionDispatch::Integration::Session.new(Rails.application)
        client.host! Discourse.current_hostname
        client.get(path, headers: { "ACCEPT" => "application/json" })
        client.response
      end

      def expect_redirect(path, destination)
        response = get_json(path)
        expect(response.status).to eq(301), response.body
        expect(response.headers.fetch("Location")).to eq("#{Discourse.base_url}#{destination}")
      end

      before do
        Fabricate(:post, topic: denied_topic)
        Fabricate(:post, topic: allowed_topic)
      end

      %i[restricted allowed].each do |direction|
        it "conceals full query permalink URLs for #{direction} destinations" do
          path = "/review-two-query?view=seasonal"
          target, decoy =
            direction == :restricted ? [denied_topic, allowed_topic] : [allowed_topic, denied_topic]
          Permalink.create!(url: path, topic: target)
          Permalink.create!(url: "/review-two-query", topic: decoy)
          expect_redirect(path, target.relative_url)
          expect_redirect("/review-two-query", decoy.relative_url)
          [path, "#{Discourse.base_url}#{path}"].each { |url| expect_url_kept(url) }
          forum_rule(denied_categories: [denied_category.id])
          aggregate_failures do
            [path, "#{Discourse.base_url}#{path}"].each { |url| expect_url_hidden(url) }
          end
        end
      end

      %i[restricted allowed].each do |direction|
        it "conceals a live #{direction} route with a conflicting permalink" do
          target, decoy =
            direction == :restricted ? [denied_topic, allowed_topic] : [allowed_topic, denied_topic]
          path = "/t/#{target.id}.json"
          Permalink.create!(url: path, topic: decoy)
          expect(Permalink.find_by_url(path).topic).to eq(decoy)
          response = get_json(path)
          expect(response.status).to eq(200), response.body
          expect(JSON.parse(response.body)).to include("id" => target.id)
          [path, "#{Discourse.base_url}#{path}"].each { |url| expect_url_kept(url) }
          forum_rule(denied_categories: [denied_category.id])
          aggregate_failures do
            [path, "#{Discourse.base_url}#{path}"].each { |url| expect_url_hidden(url) }
          end
        end
      end

      it "conceals query-sensitive permalink chains including allowed chains" do
        paths =
          [denied_topic, allowed_topic].each_with_index.map do |topic, index|
            final = "/review-two-chain/#{index}?view=seasonal"
            Permalink.create!(url: final, topic: topic)
            Permalink.create!(
              url: "/review-two-chain/#{index}",
              topic: index.zero? ? allowed_topic : denied_topic,
            )
            first = "/review-two-chain-start/#{index}"
            Permalink.create!(url: first, external_url: final)
            expect_redirect(first, final)
            expect_redirect(final, topic.relative_url)
            first
          end
        forum_rule(denied_categories: [denied_category.id])
        aggregate_failures do
          ["", Discourse.base_url].each do |base|
            expect_url_hidden("#{base}#{paths.last}")
            expect_url_hidden("#{base}#{paths.first}")
          end
        end
      end

      it "conceals topic external identifiers including allowed topics and user profiles" do
        paths =
          [denied_topic, allowed_topic].map do |topic|
            path = "/t/external_id/#{topic.external_id}"
            expect(Rails.application.routes.recognize_path(path)).to include(
              controller: "topics",
              action: "show_by_external_id",
              external_id: topic.external_id,
            )
            expect_redirect(path, "#{topic.relative_url}.json")
            path
          end
        profile = "/u/#{admin.username}"
        expect(Rails.application.routes.recognize_path(profile)).to include(controller: "users")
        forum_rule(denied_categories: [denied_category.id])
        aggregate_failures do
          ["", Discourse.base_url].each do |base|
            expect_url_hidden("#{base}#{profile}")
            expect_url_hidden("#{base}#{paths.last}")
            expect_url_hidden("#{base}#{paths.first}")
          end
        end
      end

      it "conceals unjudged engine event identifiers and an allowed core topic URL" do
        SiteSetting.discourse_events_enabled = true
        SiteSetting.discourse_post_event_enabled = true
        events =
          [denied_topic, allowed_topic].each_with_index.map do |topic, index|
            event_post = Fabricate(:post, id: 104_620_001 + index, topic: topic)
            Fabricate(:event, post: event_post)
          end
        paths =
          events.map do |event|
            path = "/discourse-post-event/events/#{event.id}.json"
            expect(Rails.application.routes.recognize_path(path)).to include(
              controller: "discourse_events/events",
              id: event.id.to_s,
            )
            response = get_json(path)
            expect(response.status).to eq(200), response.body
            expect(JSON.parse(response.body).fetch("event")).to include("id" => event.id)
            path
          end
        core_path = "/t/#{allowed_topic.id}.json"
        expect(Rails.application.routes.recognize_path(core_path)).to include(
          controller: "topics",
          id: allowed_topic.id.to_s,
        )
        response = get_json(core_path)
        expect(response.status).to eq(200), response.body
        expect(JSON.parse(response.body)).to include("id" => allowed_topic.id)
        ["", Discourse.base_url].each do |base|
          [*paths, core_path].each { |path| expect_url_kept("#{base}#{path}") }
        end
        forum_rule(denied_categories: [denied_category.id])
        aggregate_failures do
          ["", Discourse.base_url].each do |base|
            expect_url_hidden("#{base}#{core_path}")
            paths.each { |path| expect_url_hidden("#{base}#{path}") }
          end
        end
      end
    end

    describe "with local paths and site hosts in values and defaults" do
      include UploadsHelpers

      let(:denied_category) { Fabricate(:category, id: 111_730_100) }
      let(:denied_topic) { Fabricate(:topic, id: 111_730_101, category: denied_category) }
      let(:denied_post) { Fabricate(:post, id: 111_730_102, topic: denied_topic) }

      def tos_url_rows
        response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(response)
        payloads(response).map { |payload| payload.fetch("site_settings").sole }
      end

      def restrict_content(rule_kind)
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id])
        end
      end

      def expect_urls_concealed(urls, rule_kind)
        original_default = SiteSetting.defaults[:tos_url]
        external = "https://external.example/terms"
        %i[value default].each do |field|
          urls.each do |url|
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? url : external,
            )
            SiteSetting.tos_url = field == :value ? url : external
            tos_url_rows.each { |row| expect(row.fetch(field.to_s)).to eq(url) }
          end
        end
        restrict_content(rule_kind)
        aggregate_failures do
          %i[value default].each do |field|
            urls.each do |url|
              SiteSetting.defaults.set_regardless_of_locale(
                :tos_url,
                field == :default ? url : external,
              )
              SiteSetting.tos_url = field == :value ? url : external
              tos_url_rows.each do |row|
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
          it "conceals #{shape} setting values and defaults under #{rule_kind}" do
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
            expect_urls_concealed(urls, rule_kind)
          end
        end

        %i[current_hostname base_url cdn s3_cdn upload_store].each do |host|
          it "conceals #{host} host setting values and defaults under #{rule_kind}" do
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
            urls = [
              "#{base}/garden-reference",
              "#{base.sub(/\Ahttps?:/, "")}/garden-reference",
            ].uniq
            expect_urls_concealed(urls, rule_kind)
          end
        end

        it "keeps external URL values and defaults under #{rule_kind}" do
          original_default = SiteSetting.defaults[:tos_url]
          restrict_content(rule_kind)
          ["https:", "http:", ""].each do |scheme|
            value = "#{scheme}//external.example/terms"
            default = "#{scheme}//other-external.example/terms"
            SiteSetting.tos_url = value
            SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
            tos_url_rows.each do |row|
              expect(row).to include("value" => value, "default" => default)
              expect(row["redacted"]).not_to eq(true)
            end
          end
        ensure
          SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
        end

        it "keeps plain non-URL setting values and defaults under #{rule_kind}" do
          SiteSetting.title = "Seasonal garden forum"
          SiteSetting.max_tags_per_topic = 7
          restrict_content(rule_kind)
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

    describe "with browser-normalized hosts and paths" do
      let(:denied_category) { Fabricate(:category, id: 112_840_100) }
      let(:denied_topic) { Fabricate(:topic, id: 112_840_101, category: denied_category) }

      def setting_rows(names = ["tos_url"])
        response = rpc("discourse_list_site_settings", "names" => names)
        expect_usable(response)
        payloads(response).map { |payload| payload.fetch("site_settings") }
      end

      def restrict_content(rule_kind)
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id])
        end
      end

      def expect_url_concealed(url, rule_kind)
        original_default = SiteSetting.defaults[:tos_url]
        external = "https://external.example/terms"
        %i[value default].each do |field|
          SiteSetting.defaults.set_regardless_of_locale(
            :tos_url,
            field == :default ? url : external,
          )
          SiteSetting.tos_url = field == :value ? url : external
          setting_rows.each do |rows|
            expect(rows.sole).to include(
              "value" => field == :value ? url : external,
              "default" => field == :default ? url : external,
            )
          end
        end
        restrict_content(rule_kind)
        aggregate_failures do
          %i[value default].each do |field|
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? url : external,
            )
            SiteSetting.tos_url = field == :value ? url : external
            setting_rows.each do |rows|
              expect(rows.sole).to include("value" => nil, "default" => nil, "redacted" => true),
              "BROWSER LOCAL URL RETAINED in #{field}: #{url.inspect}"
            end
          end
        end
      ensure
        SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
      end

      %w[forum_content private_messages].each do |rule_kind|
        %i[percent_encoded trailing_dot uppercase unicode_site punycode_site].each do |shape|
          it "conceals #{shape} host setting values and defaults under #{rule_kind}" do
            host =
              case shape
              when :unicode_site
                "bücher.example"
              when :punycode_site
                "xn--bcher-kva.example"
              else
                "review-four-site.example"
              end
            Discourse.stubs(:current_hostname).returns(
              shape == :unicode_site ? "review-four-site.example" : host,
            )
            Discourse.stubs(:base_url).returns("https://#{host}")
            link_host =
              case shape
              when :percent_encoded
                "review-four-s%69te.example"
              when :trailing_dot
                "#{host}."
              when :uppercase
                host.upcase
              when :unicode_site
                "xn--bcher-kva.example"
              else
                "bücher.example"
              end
            expect_url_concealed("https://#{link_host}/t/secret/#{denied_topic.id}", rule_kind)
          end
        end

        %i[
          bare_relative
          special_scheme_slash
          special_scheme_relative
          backslash_relative
          backslash_absolute
          backslash_network
          backslash_short_host
        ].each do |shape|
          it "conceals #{shape} URL setting values and defaults under #{rule_kind}" do
            host = shape == :backslash_short_host ? "t" : "review-four-site.example"
            Discourse.stubs(:current_hostname).returns(host)
            Discourse.stubs(:base_url).returns("https://#{host}")
            path = "t/secret/#{denied_topic.id}"
            url =
              case shape
              when :bare_relative
                path
              when :special_scheme_slash
                "https:/#{path}"
              when :special_scheme_relative
                "https:#{path}"
              when :backslash_relative
                "\\#{path.tr("/", "\\")}"
              when :backslash_absolute
                "https:\\\\#{host}\\#{path.tr("/", "\\")}"
              when :backslash_network
                "\\\\#{host}\\#{path.tr("/", "\\")}"
              else
                "\\\\t\\\\secret"
              end
            expect_url_concealed(url, rule_kind)
          end
        end

        it "keeps external absolute URLs and plain non-URL settings under #{rule_kind}" do
          original_default = SiteSetting.defaults[:tos_url]
          value = "https://external.example/terms"
          default = "https://other-external.example/terms"
          SiteSetting.tos_url = value
          SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
          SiteSetting.title = "Seasonal garden forum"
          restrict_content(rule_kind)
          setting_rows(%w[tos_url title]).each do |rows|
            settings = rows.index_by { |row| row.fetch("setting") }
            expect(settings.fetch("tos_url")).to include("value" => value, "default" => default)
            expect(settings.fetch("title")).to include(
              "value" => SiteSetting.title,
              "default" => SiteSetting.defaults[:title],
            )
            settings.each_value { |row| expect(row["redacted"]).not_to eq(true) }
          end
        ensure
          SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
        end
      end
    end

    describe "with Unicode full stops and invisible host characters" do
      let(:denied_category) { Fabricate(:category, id: 112_850_100) }
      let(:denied_topic) { Fabricate(:topic, id: 112_850_101, category: denied_category) }

      before do
        Discourse.stubs(:current_hostname).returns("review-five-site.example")
        Discourse.stubs(:base_url).returns("https://review-five-site.example")
      end

      def tos_url_rows
        response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(response)
        payloads(response).map { |payload| payload.fetch("site_settings").sole }
      end

      def restrict_content(rule_kind)
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id])
        end
      end

      {
        ideographic_full_stop: "review-five-site\u3002example",
        fullwidth_full_stop: "review-five-site\uFF0Eexample",
        halfwidth_ideographic_full_stop: "review-five-site\uFF61example",
        percent_encoded_ideographic_full_stop: "review-five-site%E3%80%82example",
        percent_encoded_fullwidth_full_stop: "review-five-site%EF%BC%8Eexample",
        percent_encoded_halfwidth_ideographic_full_stop: "review-five-site%EF%BD%A1example",
        percent_encoded_zero_width_space: "review-five-s%E2%80%8Bite.example",
        percent_encoded_soft_hyphen: "review-five-s%C2%ADite.example",
      }.each do |shape, link_host|
        %w[forum_content private_messages].each do |rule_kind|
          it "conceals #{shape} host setting values and defaults under #{rule_kind}" do
            original_default = SiteSetting.defaults[:tos_url]
            url = "https://#{link_host}/t/secret/#{denied_topic.id}"
            external = "https://external.example/terms"
            %i[value default].each do |field|
              SiteSetting.defaults.set_regardless_of_locale(
                :tos_url,
                field == :default ? url : external,
              )
              SiteSetting.tos_url = field == :value ? url : external
              tos_url_rows.each do |row|
                expect(row).to include(
                  "value" => field == :value ? url : external,
                  "default" => field == :default ? url : external,
                )
              end
            end

            restrict_content(rule_kind)
            aggregate_failures do
              %i[value default].each do |field|
                SiteSetting.defaults.set_regardless_of_locale(
                  :tos_url,
                  field == :default ? url : external,
                )
                SiteSetting.tos_url = field == :value ? url : external
                tos_url_rows.each do |row|
                  expect(row).to include("value" => nil, "default" => nil, "redacted" => true),
                  "BROWSER HOST SETTING RETAINED in #{field}: #{url.inspect}"
                end
              end
            end
          ensure
            SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
          end
        end
      end

      %w[forum_content private_messages].each do |rule_kind|
        it "keeps external ASCII host setting values and defaults under #{rule_kind}" do
          original_default = SiteSetting.defaults[:tos_url]
          value = "https://external.example/terms"
          default = "https://other-external.example/terms"
          SiteSetting.tos_url = value
          SiteSetting.defaults.set_regardless_of_locale(:tos_url, default)
          restrict_content(rule_kind)
          tos_url_rows.each do |row|
            expect(row).to include("value" => value, "default" => default)
            expect(row["redacted"]).not_to eq(true)
          end
        ensure
          SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
        end
      end
    end

    describe "with IP and IDNA host notations" do
      let(:denied_category) { Fabricate(:category, id: 112_860_100) }
      let(:denied_topic) { Fabricate(:topic, id: 112_860_101, category: denied_category) }

      def tos_url_rows
        response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
        expect_usable(response)
        payloads(response).map { |payload| payload.fetch("site_settings").sole }
      end

      def restrict_content(rule_kind)
        if rule_kind == "private_messages"
          McpContentRule.create!(rule_kind:, config: {})
        else
          forum_rule(denied_categories: [denied_category.id])
        end
      end

      {
        percent_encoded_capital_sharp_s: %w[xn--fa-hia.example fa%E1%BA%9E.example],
        unicode_capital_sharp_s: ["xn--fa-hia.example", "fa\u1E9E.example"],
        ipv4_short_dotted: %w[127.0.0.1 127.1],
        ipv4_decimal_integer: %w[127.0.0.1 2130706433],
        ipv4_hex_integer: %w[127.0.0.1 0x7f000001],
        ipv4_octal_dotted: %w[127.0.0.1 0177.0.0.1],
        ipv4_leading_zero_dotted: %w[127.0.0.1 127.000.000.001],
        ipv4_octal_integer: %w[127.0.0.1 017700000001],
        canonical_punycode: %w[xn--fa-hia.example xn--fa-hia.example],
        canonical_ipv4: %w[127.0.0.1 127.0.0.1],
      }.each do |shape, (site_host, link_host)|
        %w[forum_content private_messages].each do |rule_kind|
          it "conceals #{shape} host setting values and defaults under #{rule_kind}" do
            Discourse.stubs(:current_hostname).returns(site_host)
            Discourse.stubs(:base_url).returns("https://#{site_host}")
            original_default = SiteSetting.defaults[:tos_url]
            url = "https://#{link_host}/t/secret/#{denied_topic.id}"
            external = "https://external.example/terms"
            %i[value default].each do |field|
              SiteSetting.defaults.set_regardless_of_locale(
                :tos_url,
                field == :default ? url : external,
              )
              SiteSetting.tos_url = field == :value ? url : external
              tos_url_rows.each do |row|
                expect(row).to include(
                  "value" => field == :value ? url : external,
                  "default" => field == :default ? url : external,
                )
              end
            end

            restrict_content(rule_kind)
            aggregate_failures do
              %i[value default].each do |field|
                SiteSetting.defaults.set_regardless_of_locale(
                  :tos_url,
                  field == :default ? url : external,
                )
                SiteSetting.tos_url = field == :value ? url : external
                tos_url_rows.each do |row|
                  expect(row).to include("value" => nil, "default" => nil, "redacted" => true),
                  "BROWSER HOST SETTING RETAINED in #{field}: #{url.inspect}"
                end
              end
            end
          ensure
            SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
          end
        end
      end

      {
        ipv6_literal: "https://[2001:db8::6]/page",
        ipv6_with_port: "https://[2001:db8::6]:8443/page",
        ipv6_with_userinfo: "https://visitor:password@[2001:db8::6]/page",
        ipv6_with_userinfo_and_port: "https://visitor:password@[2001:db8::6]:8443/page",
        ascii_host: "https://external.example/page",
        canonical_ipv4: "https://192.0.2.6/page",
      }.each do |shape, url|
        %w[forum_content private_messages].each do |rule_kind|
          it "keeps external #{shape} setting values and defaults under #{rule_kind}" do
            Discourse.stubs(:current_hostname).returns("127.0.0.1")
            Discourse.stubs(:base_url).returns("https://127.0.0.1")
            original_default = SiteSetting.defaults[:tos_url]
            external = "https://other-external.example/terms"
            %i[value default].each do |field|
              SiteSetting.defaults.set_regardless_of_locale(
                :tos_url,
                field == :default ? url : external,
              )
              SiteSetting.tos_url = field == :value ? url : external
              tos_url_rows.each do |row|
                expect(row).to include(
                  "value" => field == :value ? url : external,
                  "default" => field == :default ? url : external,
                )
              end
            end

            restrict_content(rule_kind)
            aggregate_failures do
              %i[value default].each do |field|
                SiteSetting.defaults.set_regardless_of_locale(
                  :tos_url,
                  field == :default ? url : external,
                )
                SiteSetting.tos_url = field == :value ? url : external
                tos_url_rows.each do |row|
                  expect(row).to include(
                    "value" => field == :value ? url : external,
                    "default" => field == :default ? url : external,
                  ),
                  "EXTERNAL HOST SETTING REDACTED in #{field}: #{url.inspect}"
                  expect(row["redacted"]).not_to eq(true)
                end
              end
            end
          ensure
            SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
          end
        end
      end
    end

    describe "with an invalid UTF-8 host" do
      %w[forum_content private_messages].each do |kind|
        %i[value default].each do |field|
          it "conceals an invalid UTF-8 decoded host in setting #{field} under #{kind} without an error" do
            original_default = SiteSetting.defaults[:tos_url]
            malformed = "https://%FF.example/page"
            external = "https://external.example/terms"
            SiteSetting.defaults.set_regardless_of_locale(
              :tos_url,
              field == :default ? malformed : external,
            )
            SiteSetting.tos_url = field == :value ? malformed : external

            unrestricted = rpc("discourse_list_site_settings", "names" => ["tos_url"])
            expect_usable(unrestricted)
            payloads(unrestricted).each do |payload|
              expect(payload.fetch("site_settings").sole).to include(field.to_s => malformed)
            end

            if kind == "forum_content"
              forum_rule
            else
              McpContentRule.create!(rule_kind: kind, config: {})
            end

            response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
            expect_usable(response)
            payloads(response).each do |payload|
              expect(payload.fetch("site_settings").sole).to include(
                "value" => nil,
                "default" => nil,
                "redacted" => true,
              )
            end
          ensure
            SiteSetting.defaults.set_regardless_of_locale(:tos_url, original_default)
          end
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
