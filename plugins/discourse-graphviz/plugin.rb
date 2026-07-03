# frozen_string_literal: true

# name: discourse-graphviz
# about: Provides the ability to add graphs to posts using the DOT language.
# meta_topic_id: 97554
# version: 0.0.1
# authors: Maja Komel, Joffrey Jaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-graphviz

enabled_site_setting :discourse_graphviz_enabled

register_svg_icon "diagram-project"
register_asset "stylesheets/common/graphviz.scss"
