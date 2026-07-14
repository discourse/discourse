# frozen_string_literal: true

# name: stylesheet-targets-plugin
# about: fixture used to exercise per-target plugin stylesheet registration
# version: 0.1
# authors: Discourse

register_asset "stylesheets/common/common.scss"
register_asset "stylesheets/mobile/mobile.scss", :mobile
register_asset "stylesheets/desktop/desktop.scss", :desktop
register_asset "stylesheets/admin/admin.scss", :admin
