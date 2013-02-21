class DiscourseVersionCheckSerializer < ApplicationSerializer
  attributes :latest_version, :critical_updates, :installed_version, :installed_sha

  self.root = false
end