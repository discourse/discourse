# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # One home for every place `disco upload` short-circuits Discourse's
      # `UploadCreator` hot paths, so the migration-only monkeypatches are
      # greppable in a single file instead of scattered around. Each is safe only
      # because a migration is a single, resumable, batch process — not the
      # multi-request production app `UploadCreator` is written for.
      #
      # The measured deltas below come from the profiling harness in
      # `migrations/tooling/scripts/benchmarks/` (`upload_creator_profile.rb`);
      # `RESULTS.md` has the full breakdown and the before/after table.
      module DiscoursePatches
        # Thread-local flag set around `UploadCreator#create_for`, read by the
        # `DistributedMutex` patch below.
        MUTEX_BYPASS_KEY = :migrations_upload_creator_running

        class << self
          def apply!
            return if @applied
            @applied = true

            disable_synchronous_commit!
            memoize_uploader_user!
            upsert_user_uploads!
            bypass_upload_distributed_mutex!
          end

          # The uploader is always `Discourse::SYSTEM_USER_ID` for a migration, so
          # the user row is constant across the whole run. Loaded once here (on the
          # main thread, before any worker starts) and shared read-only.
          def uploader_user
            @uploader_user ||= ::User.find_by(id: Discourse::SYSTEM_USER_ID)
          end

          def bypassing_upload_mutex?
            Thread.current[MUTEX_BYPASS_KEY]
          end

          private

          # THE big lever. Every `create_for` commits three separate write
          # transactions, and with the default `synchronous_commit=on` each COMMIT
          # blocks on a WAL fsync — ~5.5-8 ms apiece on the profiling box, so
          # ~16-24 ms/upload of pure durability latency. That is ~100% of an
          # upload's SQL time (the server executes in µs) and dominates an
          # attachment's whole cost.
          #
          # Turning `synchronous_commit` off lets COMMIT return without waiting for
          # the WAL flush. The only thing at risk is the last fraction of a second
          # of commits on an OS/hardware crash — and for this importer those rows
          # simply reprocess on the next run: it is resume-safe by design (each
          # task skips ids already recorded), so a lost tail is re-derived, never
          # lost data.
          #
          # Applied session-scoped through the AR pool's `:variables` config rather
          # than `ALTER DATABASE`: Rails runs `SET SESSION synchronous_commit TO
          # 'off'` in `configure_connection` on every connection it opens or
          # reconnects, so it covers every session the workers check out, survives
          # the adaptive gate's connection churn, needs no reset (it dies with the
          # process), and never touches other sessions on the database.
          def disable_synchronous_commit!
            config = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup
            (config[:variables] ||= {})[:synchronous_commit] = "off"
            ActiveRecord::Base.establish_connection(config)
          end

          # `UploadValidator` calls `upload.user&.staff?` several times per upload,
          # each firing a `User Load` for the same constant system user (~0.2-0.5 ms
          # + a round-trip per upload). Return the memoized row instead. Warmed here
          # so the workers only ever read it. Measured delta: one `User Load` query
          # removed per upload.
          def memoize_uploader_user!
            ::Upload.prepend(UploaderUser)
            uploader_user
          end

          # `create_for` does a find-or-create on the `user_uploads` join, which is
          # two round-trips (SELECT then INSERT). The table has a unique index on
          # `(upload_id, user_id)`, so a single `INSERT … ON CONFLICT DO NOTHING`
          # keeps the same idempotency (a re-run's existing row is left untouched)
          # in one round-trip. Measured delta: one `UserUpload Load` query removed
          # per upload.
          def upsert_user_uploads!
            ::UserUpload.singleton_class.prepend(UserUploadUpsert)
          end

          # `create_for` wraps its whole body in
          # `DistributedMutex.synchronize("upload_<user>_<filename>")`, a Redis lock
          # that guards two creators racing on the same sha1. A single-writer import
          # never races itself, and the one real race it can hit — two workers
          # creating the same sha1 — is already handled downstream: the `uploads`
          # sha1 unique index rejects the loser's INSERT and the pipeline's retry
          # policy recovers by looking up the winner's row (see the
          # `ActiveRecord::RecordNotUnique` recover handler in `Tasks::Uploader`).
          # So the lock is redundant here; bypassing it removes 2-3 Redis
          # round-trips per upload (negligible against image cooking on a local
          # Redis, real network hops on production infra).
          #
          # Scoped precisely to `create_for` via a thread-local rather than by
          # matching the lock key, so no other `DistributedMutex` use is affected.
          def bypass_upload_distributed_mutex!
            ::UploadCreator.prepend(CreatorMutexScope)
            ::DistributedMutex.singleton_class.prepend(MutexBypass)
          end
        end

        module UploaderUser
          def user
            if user_id == Discourse::SYSTEM_USER_ID && !association(:user).loaded?
              DiscoursePatches.uploader_user
            else
              super
            end
          end
        end

        module UserUploadUpsert
          def find_or_create_by!(attributes, &)
            row = attributes.symbolize_keys
            row[:created_at] ||= Time.zone.now
            insert_all([row], unique_by: %i[upload_id user_id])
            nil
          end
        end

        module CreatorMutexScope
          def create_for(*)
            previous = Thread.current[DiscoursePatches::MUTEX_BYPASS_KEY]
            Thread.current[DiscoursePatches::MUTEX_BYPASS_KEY] = true
            super
          ensure
            Thread.current[DiscoursePatches::MUTEX_BYPASS_KEY] = previous
          end
        end

        module MutexBypass
          def synchronize(_key, **)
            return yield if DiscoursePatches.bypassing_upload_mutex?
            super
          end
        end
      end
    end
  end
end
