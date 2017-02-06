class Sanitize
  module Config

    HTTP_PROTOCOLS ||= ['http', 'https', :relative].freeze

    ONEBOX ||= freeze_config merge(RELAXED,
      elements: RELAXED[:elements] + %w[audio embed iframe source video],

      attributes: merge(RELAXED[:attributes],
        'audio'  => %w[controls],
        'embed'  => %w[height src type width],
        'iframe' => %w[allowfullscreen frameborder height scrolling src width],
        'source' => %w[src type],
        'video'  => %w[controls height loop width],
        'div'    => [:data], # any data-* attributes
      ),

      protocols: merge(RELAXED[:protocols],
        'embed'  => { 'src' => HTTP_PROTOCOLS },
        'iframe' => { 'src' => HTTP_PROTOCOLS },
        'source' => { 'src' => HTTP_PROTOCOLS },
      ),
    )
  end
end
