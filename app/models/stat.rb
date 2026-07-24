# frozen_string_literal: true

class Stat
  def initialize(name, expose_via_api: false, stat_type: nil, &block)
    @name = name
    @expose_via_api = expose_via_api
    @block = block
    @stat_type = stat_type
    validate_stat_type
  end

  attr_reader :name, :expose_via_api, :stat_type

  def calculate
    if @stat_type
      { stat_type.to_sym => @block.call.transform_keys { |key| build_key(key) } }
    else
      @block.call.transform_keys { |key| build_key(key) }
    end
  rescue StandardError => err
    Discourse.warn_exception(err, message: "Unexpected error when collecting #{@name} About stats.")
    {}
  end

  def self.all_stats
    calculate(_all_stats)
  end

  def self.api_stats
    calculate(_api_stats)
  end

  private

  def validate_stat_type
    return if !@stat_type
    if !@stat_type.is_a?(Symbol) || !@stat_type.match?(/^[a-z0-9_]+$/) || @stat_type.length > 20
      raise ArgumentError,
            "Stat type (#{@stat_type}) must be a valid symbol, is all lowercase, only contains letters and numbers, and is < 20 characters"
    end
  end

  # The key vars here are the keys in the result of the stat block,
  # e.g. 7_days, 30_days, count
  def build_key(key)
    :"#{@name}_#{key}"
  end

  def self._all_stats
    core_stats.concat(plugin_stats)
  end

  def self.calculate(stats)
    stats.map { |stat| stat.calculate }.reduce({}) { |memo, result| memo.deep_merge(result) }
  end

  def self.core_stats
    list = [
      Stat.new("topics", expose_via_api: true) { Statistics.topics },
      Stat.new("posts", expose_via_api: true) { Statistics.posts },
      Stat.new("users", expose_via_api: true) { Statistics.users },
      Stat.new("active_users", expose_via_api: true) { Statistics.active_users },
      Stat.new("likes", expose_via_api: true) { Statistics.likes },
      Stat.new("participating_users", expose_via_api: true) { Statistics.participating_users },
    ]

    if SiteSetting.display_eu_visitor_stats
      list.concat(
        [
          Stat.new("visitors", expose_via_api: true) { Statistics.visitors },
          Stat.new("eu_visitors", expose_via_api: true) { Statistics.eu_visitors },
        ],
      )
    end

    list
  end

  def self._api_stats
    _all_stats.select { |stat| stat.expose_via_api }
  end

  def self.plugin_stats
    DiscoursePluginRegistry.stats
  end

  private_class_method :_all_stats, :calculate, :core_stats, :_api_stats, :plugin_stats
end
