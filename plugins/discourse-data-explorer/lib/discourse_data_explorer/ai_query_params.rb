# frozen_string_literal: true

module DiscourseDataExplorer
  class AiQueryParams
    def self.sample_for(query, current_user:)
      new(query, current_user: current_user).sample
    end

    def initialize(query, current_user:)
      @query = query
      @current_user = current_user
    end

    def sample
      query
        .params
        .each_with_object({}) do |param, params|
          next if param.default.present? || param.internal?

          value = sample_value(param)
          params[param.identifier] = value if value.present? || !param.nullable
        end
    end

    private

    attr_reader :query, :current_user

    def sample_value(param)
      case param.type
      when :int
        "1"
      when :bigint
        "1"
      when :boolean
        "true"
      when :string
        "sample"
      when :date
        sample_date(param.identifier)
      when :time
        "00:00"
      when :datetime
        sample_datetime(param.identifier)
      when :double
        "1.0"
      when :user_id
        current_user.username
      when :post_id
        Post.where(deleted_at: nil).order(:id).pick(:id).to_s
      when :topic_id
        Topic.where(deleted_at: nil).order(:id).pick(:id).to_s
      when :category_id
        Category.where(read_restricted: false).order(:id).pick(:id).to_s
      when :group_id
        Group.order(:name).pick(:name).to_s
      when :badge_id
        Badge.order(:id).pick(:id).to_s
      when :int_list
        "1,2"
      when :string_list
        "sample,example"
      when :user_list
        current_user.username
      when :group_list
        Group.order(:name).pick(:name).to_s
      end
    end

    def sample_date(identifier)
      if identifier.match?(/\A(start|from|begin)/i)
        30.days.ago.to_date.iso8601
      elsif identifier.match?(/\A(end|to|until)/i)
        Date.current.iso8601
      else
        Date.current.iso8601
      end
    end

    def sample_datetime(identifier)
      if identifier.match?(/\A(start|from|begin)/i)
        30.days.ago.strftime("%Y-%m-%d %H:%M")
      elsif identifier.match?(/\A(end|to|until)/i)
        Time.zone.now.strftime("%Y-%m-%d %H:%M")
      else
        Time.zone.now.strftime("%Y-%m-%d %H:%M")
      end
    end
  end
end
