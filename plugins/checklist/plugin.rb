# frozen_string_literal: true

# name: checklist
# about: Add checklist support to Discourse
# version: 1.0
# authors: Discourse Team
# meta_topic_id: 36362
# url: https://github.com/discourse/discourse/tree/main/plugins/checklist

enabled_site_setting :checklist_enabled

register_asset "stylesheets/checklist.scss"
register_svg_icon "spinner"
hide_plugin
