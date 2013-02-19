class DiscourseVersionCheckSerializer < ApplicationSerializer
  attributes :latest_version, :installed_version, :critical_updates

  self.root = false
end