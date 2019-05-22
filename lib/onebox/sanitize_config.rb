# frozen_string_literal: true

class Sanitize
  module Config

    HTTP_PROTOCOLS ||= ['http', 'https', :relative].freeze

    ONEBOX ||= freeze_config merge(RELAXED,
      elements: RELAXED[:elements] + %w[audio embed iframe source video svg path],

      attributes: {
        'a' => RELAXED[:attributes]['a'] + %w(target),
        'audio' => %w[controls],
        'embed' => %w[height src type width],
        'iframe' => %w[allowfullscreen frameborder height scrolling src width data-original-href],
        'source' => %w[src type],
        'video' => %w[controls height loop width autoplay muted poster],
        'path' => %w[d],
        'svg' => ['aria-hidden', 'width', 'height', 'viewbox'],
        'div' => [:data], # any data-* attributes
      },

      add_attributes: {
        'iframe' => {
          'seamless' => 'seamless',
          'sandbox' => 'allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox' \
                       ' allow-presentation',
        }
      },

      transformers: (RELAXED[:transformers] || []) + [
        lambda do |env|
          next unless env[:node_name] == 'a'
          a_tag = env[:node]
          a_tag['href'] ||= '#'
          if a_tag['href'] =~ %r{^(?:[a-z]+:)?//}
            a_tag['rel'] = 'nofollow noopener'
          else
            a_tag.remove_attribute('target')
          end
        end
      ],

      protocols: {
        'embed' => { 'src' => HTTP_PROTOCOLS },
        'iframe' => { 'src' => HTTP_PROTOCOLS },
        'source' => { 'src' => HTTP_PROTOCOLS },
      },

      css: {
        properties: RELAXED[:css][:properties] + %w[--aspect-ratio]
      }
    )
  end
end
