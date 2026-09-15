# frozen_string_literal: true

module DiscourseRewind
  # Service responsible to fetch a single report by index.
  #
  # NOTE: When changing any report implementations, please
  # also update FetchReportsHelper::REWIND_REPORT_VERSION
  # to invalidate caches.
  #
  # @example
  #  ::DiscourseRewind::FetchReport.call(
  #    guardian: guardian,
  #    params: { index: 3, for_user_username: 'codinghorror' }
  #  )
  #
  class FetchReport
    include Service::Base
    include DiscourseRewind::FetchReportsHelper

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :index of the report
    #   @option params [String] :for_user_username (optional) username of the user to see the rewind for, otherwise the guardian user is used
    #   @return [Service::Base::Context]

    params do
      attribute :index, :integer
      attribute :for_user_username, :string

      validates :index, presence: true, numericality: { greater_than_or_equal_to: 0 }
    end

    model :for_user # see FetchReportsHelper#fetch_for_user
    model :year # see FetchReportsHelper#fetch_year
    model :date
    model :report

    private

    def fetch_date(params:, year:)
      Time.zone.local(year).all_year
    end

    def fetch_report(params:, for_user:, year:, date:, guardian:)
      report_class = FetchReports::REPORTS[params.index]
      return if !report_class

      report_name = report_class.name.demodulize
      report = load_single_report_from_cache(for_user.id, year, report_name)
      if !report
        report = report_class.call(date:, user: for_user)
        cache_single_report(for_user.id, year, report_name, report.as_json)
      end

      report = filter_report_for_viewer(report, guardian, report_class) if report_class.in?(
        FetchReports::VISIBILITY_FILTERED_REPORTS,
      )
      report
    end

    def filter_report_for_viewer(report, guardian, report_class)
      case report_class.name
      when Action::BestTopics.name
        filter_best_topics_for_viewer(report, guardian)
      when Action::BestPosts.name
        filter_best_posts_for_viewer(report, guardian)
      end
    end

    def filter_best_topics_for_viewer(report, guardian)
      topic_ids = report[:data].pluck(:topic_id)
      visible_topic_ids = guardian.can_see_topic_ids(topic_ids:)
      eligible_topic_ids =
        Topic
          .visible
          .where(id: visible_topic_ids, deleted_at: nil)
          .where.not(archetype: Archetype.private_message)
          .joins(:category)
          .where("NOT categories.read_restricted")
          .pluck(:id)

      report.merge(data: report[:data].select { |topic| topic[:topic_id].in?(eligible_topic_ids) })
    end

    def filter_best_posts_for_viewer(report, guardian)
      topic_ids = report[:data].pluck(:topic_id)
      visible_topic_ids = guardian.can_see_topic_ids(topic_ids:)
      eligible_post_keys =
        Post
          .public_posts
          .visible
          .joins(topic: :category)
          .where(
            topic_id: visible_topic_ids,
            post_number: report[:data].pluck(:post_number),
            deleted_at: nil,
          )
          .where("NOT categories.read_restricted")
          .where.not(post_type: Post.types[:whisper])
          .pluck(:topic_id, :post_number)

      report.merge(
        data:
          report[:data].select do |post|
            [post[:topic_id], post[:post_number]].in?(eligible_post_keys)
          end,
      )
    end
  end
end
