# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Patches to Discourse's upload code that `disco upload` applies, so that
      # `UploadCreator` does less work per upload. They are all in this file, so
      # they are easy to find. Each one is only safe because a migration is a
      # single, resumable batch process, and not the web app with many parallel
      # requests that `UploadCreator` is written for.
      module DiscoursePatches
        # Thread-local flag set around `UploadCreator#create_for`, read by the
        # `DistributedMutex` patch below.
        MUTEX_BYPASS_KEY = :migrations_upload_creator_running

        class << self
          def apply!
            return if @applied
            @applied = true

            memoize_uploader_user!
            upsert_user_uploads!
            bypass_upload_distributed_mutex!
          end

          # `disco upload` creates every upload for `Discourse::SYSTEM_USER_ID`, so
          # the row is loaded once, on the main thread before any worker starts,
          # and the workers only read it.
          def uploader_user
            @uploader_user ||= ::User.find_by(id: Discourse::SYSTEM_USER_ID)
          end

          def bypassing_upload_mutex?
            Thread.current[MUTEX_BYPASS_KEY]
          end

          private

          # `Upload#user` returns the loaded system user instead of querying the
          # same row again for every upload.
          def memoize_uploader_user!
            ::Upload.prepend(UploaderUser)
            uploader_user
          end

          # `UserUpload.find_or_create_by!` becomes a single
          # `INSERT … ON CONFLICT DO NOTHING` on the unique `(upload_id, user_id)`
          # index: one query instead of a SELECT and an INSERT. An existing row
          # stays as it is, so a second call for the same pair is safe. It
          # returns nil instead of the record.
          def upsert_user_uploads!
            ::UserUpload.singleton_class.prepend(UserUploadUpsert)
          end

          # `DistributedMutex.synchronize` does not take its Redis lock while
          # `UploadCreator#create_for` runs on the same thread. The Redis lock is
          # not needed there: `UploadCreationService` already makes sure that
          # uploads with the same content are not created at the same time, with
          # an in-process lock per content hash.
          #
          # A thread-local flag set around `create_for` turns the bypass on, not
          # the lock key, so no other `DistributedMutex` use is affected.
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
