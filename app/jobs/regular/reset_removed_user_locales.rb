# frozen_string_literal: true

module Jobs
  class ResetRemovedUserLocales < ::Jobs::Base
    def execute(args)
      removed_locales = args.fetch(:locales)
      User
        .real
        .where(locale: removed_locales)
        .in_batches(of: 1_000, use_ranges: true) do |batch|
          updated =
            DistributedMutex.synchronize("site_setting/update") do
              SiteSetting.refresh!
              locales = removed_locales - SiteSetting.interface_locales
              next false if locales.empty?

              batch.where(locale: locales).update_all(locale: nil)
              true
            end
          break if !updated
        end
    end
  end
end
