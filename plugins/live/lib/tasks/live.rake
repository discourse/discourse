# frozen_string_literal: true

# Emergency lever: drops every pinned live-room transport so each room's
# next join re-resolves against current settings. Calls already in progress
# are not interrupted, but their next joiner may land on a different
# transport than the current occupants — prefer the per-room "End live call"
# admin action unless the media server is already unreachable.
desc "Clear all pinned live room transports"
task "live:clear_transport_pins" => :environment do
  cleared = 0

  Discourse
    .redis
    .scan_each(match: "#{Live::ParticipantTracker::KEY_NAMESPACE}:*:transport") do |key|
      Discourse.redis.del(key)
      cleared += 1
    end

  puts "Cleared #{cleared} transport pin(s)."
end
