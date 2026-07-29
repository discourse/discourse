# frozen_string_literal: true
module AdminDashboardTestFixtures
  class CategoryIdSetting
    def self.permit = [:category_id]

    def self.validate(attrs)
      { "category_id" => attrs[:category_id].to_i }
    end
  end

  class BulkReportsProvider < AdminDashboard::Reports::SourceProvider
    def self.source_name = "fake_source"

    def self.fetch_many(identifiers, guardian:, filters: {})
      identifiers.each_with_object({}) do |identifier, results|
        results[identifier.to_s] = { id: identifier.to_s, filters: }
      end
    end
  end

  class FakeAvailableReportsProvider < AdminDashboard::Reports::SourceProvider
    def self.source_name = "a_fake_source"
    def self.label = "Fake"
    def self.universe
      [%w[banana Banana], %w[date Date], %w[fig Fig]].map do |id, fruit|
        AdminDashboard::Reports::ResolvedReport.new(
          source: source_name,
          identifier: id,
          title: "Zfruit #{fruit}",
          description: "Desc #{id}",
          label:,
          url: "/fake/#{id}",
        )
      end
    end
    def self.list_all(search: nil, after: nil, limit: nil)
      items = universe
      items =
        items.select { |item| item.title.downcase.include?(search.downcase) } if search.present?
      seek(items, after:, limit:)
    end
    def self.resolve_many(identifiers, guardian:)
      universe
        .select { |item| identifiers.map(&:to_s).include?(item.identifier) }
        .index_by(&:identifier)
    end
  end

  class AlternateAvailableReportsProvider < AdminDashboard::Reports::SourceProvider
    def self.source_name = "b_alt_source"
    def self.label = "Alt"
    def self.universe
      [%w[apple Apple], %w[cherry Cherry], %w[egg Egg]].map do |id, fruit|
        AdminDashboard::Reports::ResolvedReport.new(
          source: source_name,
          identifier: id,
          title: "Zfruit #{fruit}",
          description: nil,
          label:,
          url: nil,
        )
      end
    end
    def self.list_all(search: nil, after: nil, limit: nil)
      items = universe
      items =
        items.select { |item| item.title.downcase.include?(search.downcase) } if search.present?
      seek(items, after:, limit:)
    end
    def self.resolve_many(_identifiers, guardian:)
      {}
    end
  end

  class WideAvailableReportsProvider < AdminDashboard::Reports::SourceProvider
    def self.source_name = "c_wide_source"
    def self.label = "Wide"
    def self.universe
      (1..40).map do |index|
        padded = format("%02d", index)
        AdminDashboard::Reports::ResolvedReport.new(
          source: source_name,
          identifier: "row_#{padded}",
          title: "Widerow #{padded}",
          description: nil,
          label:,
          url: nil,
        )
      end
    end
    def self.list_all(search: nil, after: nil, limit: nil)
      items = universe
      items =
        items.select { |item| item.title.downcase.include?(search.downcase) } if search.present?
      seek(items, after:, limit:)
    end
    def self.resolve_many(_identifiers, guardian:)
      {}
    end
  end

  class LayoutReportsProvider < AdminDashboard::Reports::SourceProvider
    def self.source_name = "fake_source"
    def self.label = "Fake"
    def self.accessible_ids(identifiers, guardian:)
      identifiers.map(&:to_s).reject { |identifier| identifier == "forbidden" }.to_set
    end
  end

  def configure_dashboard_sections(visible_ids:)
    hidden = AdminDashboardSectionConfiguration::KNOWN_SECTIONS - visible_ids
    ordered =
      visible_ids.map { |id| { id:, visible: true } } + hidden.map { |id| { id:, visible: false } }
    AdminDashboardSectionConfiguration.update(ordered, actor: Discourse.system_user)
  end

  def populate_new_features(date1: nil, date2: nil)
    Discourse.redis.set(
      "new_features",
      MultiJson.dump(
        [
          {
            "id" => "1",
            "emoji" => "🤾",
            "title" => "Cool Beans",
            "description" => "Now beans are included",
            "created_at" => date1 || 40.minutes.ago,
          },
          {
            "id" => "2",
            "emoji" => "🙈",
            "title" => "Fancy Legumes",
            "description" => "Legumes too!",
            "created_at" => date2 || 20.minutes.ago,
          },
        ],
      ),
    )
  end
end
