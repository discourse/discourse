# frozen_string_literal: true

module WebsiteBrand
  # Color signals found on a website, grouped into clusters of colors that
  # look alike and ranked by how strongly they point at the brand.
  class Signals
    # Colors closer than this in OKLab look like the same color.
    CLUSTER_DISTANCE = 0.07
    # However often a color appears in passing, it can't outweigh a deliberate
    # signal such as a theme color or a button.
    WEAK_SOURCES = %i[background text nested_link].freeze
    MAX_WEAK_WEIGHT = 2
    # Large stylesheets mention thousands of colors, and only the most used
    # can matter, so only these are grouped.
    MAX_CLUSTERED_COLORS = 400
    MIN_ACCENT_HUE_DIFFERENCE = 35
    MIN_ACCENT_WEIGHT = 1.5
    MEDIUM_CONFIDENCE_WEIGHT = 4
    HIGH_CONFIDENCE_WEIGHT = 8
    MAX_CANDIDATES = 4

    Tally =
      Struct.new(:strong, :weak) do
        def weight
          strong + [weak, MAX_WEAK_WEIGHT].min
        end

        def merge!(other)
          self.strong += other.strong
          self.weak += other.weak
        end
      end

    Cluster = Struct.new(:hex, :lab, :tally) { delegate :weight, to: :tally }

    def initialize
      @tallies = {}
    end

    def add(hex, weight:, source:)
      return if hex.nil?

      tally = (@tallies[hex] ||= Tally.new(0.0, 0.0))
      if WEAK_SOURCES.include?(source)
        tally.weak += weight
      else
        tally.strong += weight
      end
      @ranked = nil
    end

    def brand
      vivid.first&.hex
    end

    # A second brand color, with a clearly different hue.
    def accent
      brand_cluster = vivid.first
      return if brand_cluster.nil?

      vivid
        .drop(1)
        .find do |cluster|
          cluster.weight >= MIN_ACCENT_WEIGHT &&
            Color.hue_difference(cluster.hex, brand_cluster.hex) > MIN_ACCENT_HUE_DIFFERENCE
        end
        &.hex
    end

    def confidence
      weight = vivid.first&.weight.to_f
      if weight >= HIGH_CONFIDENCE_WEIGHT
        :high
      elsif weight >= MEDIUM_CONFIDENCE_WEIGHT
        :medium
      else
        :low
      end
    end

    # The likeliest brand colors, strongest first, for an admin to pick from.
    def candidates
      vivid.first(MAX_CANDIDATES).map(&:hex)
    end

    private

    # Clusters strongest first. Each cluster takes the hex of the strongest
    # color in it, and ties go to the color found first.
    def ranked
      @ranked ||=
        strongest_tallies
          .each_with_object([]) { |(hex, tally), clusters| join_cluster(clusters, hex, tally) }
          .each_with_index
          .sort_by { |cluster, index| [-cluster.weight, index] }
          .map(&:first)
    end

    def strongest_tallies
      @tallies
        .each_with_index
        .sort_by { |(_, tally), index| [-tally.weight, index] }
        .first(MAX_CLUSTERED_COLORS)
        .map(&:first)
    end

    def join_cluster(clusters, hex, tally)
      lab = Color.oklab(hex)
      cluster = clusters.find { |candidate| distance(candidate.lab, lab) < CLUSTER_DISTANCE }
      if cluster.nil?
        cluster = Cluster.new(hex, lab, Tally.new(0.0, 0.0))
        clusters << cluster
      end

      cluster.tally.merge!(tally)
    end

    def distance(lab, other_lab)
      Math.sqrt(lab.zip(other_lab).sum { |value, other| (value - other)**2 })
    end

    def vivid
      ranked.select { |cluster| Color.vivid?(cluster.hex) }
    end
  end
end
