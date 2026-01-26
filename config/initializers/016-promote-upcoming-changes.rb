# frozen_string_literal: true
#
# Promotes upcoming changes (defined in site_settings.yml) based
# on their status, and the configured promote_upcoming_changes_on_status
# site setting for the site.

require "upcoming_changes"
require "upcoming_changes/auto_promotion_initializer"

Rails.application.config.after_initialize { UpcomingChanges::AutoPromotionInitializer.call }
