# frozen_string_literal: true

module BulkImport::DiscourseMerge
  module MatchedAvatars
    def self.decisions(matches, source, destination)
      matches
        .group_by { |match| match.fetch("destination_user_id") }
        .sort
        .map do |id, accounts|
          member = destination.fetch(id)
          sources =
            accounts
              .map { |match| source.fetch(match.fetch("source_user_id")) }
              .sort_by { |row| row.fetch("id").to_i }
          donor = sources.find { |row| row["public_avatar_id"] }
          choice, upload =
            if member["uploaded_avatar_id"]
              ["destination", member.fetch("uploaded_avatar_id").to_i]
            elsif donor
              ["source", donor.fetch("public_avatar_id").to_i]
            else
              ["default", nil]
            end
          {
            "destination_user_id" => id,
            "username" => member.fetch("username"),
            "sources" => sources.to_h { |row| [row.fetch("id").to_s, row.fetch("username")] },
            "choice" => choice,
            "upload_id" => upload,
          }
        end
    end

    def self.destination_upload(decision, uploads)
      id = decision.fetch("upload_id")
      decision.fetch("choice") == "source" ? uploads.fetch(id) : id
    end

    def self.adopt!(decisions, users, uploads)
      User.transaction do
        decisions.each do |decision|
          next unless decision.fetch("choice") == "source"
          id = decision.fetch("destination_user_id")
          upload = destination_upload(decision, uploads)
          unless decision.fetch("sources").keys.all? { |source| users.fetch(source.to_i) == id } &&
                   Upload.unscoped.exists?(id: upload, secure: false, access_control_post_id: nil)
            raise Error, "Invalid mapped avatar for destination user #{id}"
          end
          updated =
            User
              .unscoped
              .where(id: id, uploaded_avatar_id: nil)
              .update_all(uploaded_avatar_id: upload)
          raise Error, "Destination avatar changed for user #{id}" unless updated == 1
          UploadReference.insert_all(
            [{ target_type: "User", target_id: id, upload_id: upload }],
            unique_by: %i[upload_id target_type target_id],
          )
        end
      end
    end

    def self.verify!(decisions, maps)
      ids = decisions.pluck("destination_user_id")
      profiles =
        User
          .unscoped
          .where(id: ids)
          .pluck(:id, :username, :uploaded_avatar_id)
          .to_h { |id, name, upload| [id, [name, upload]] }
      references =
        UploadReference
          .where(target_type: "User", target_id: ids)
          .pluck(:target_id, :upload_id)
          .to_set
      decisions.each do |decision|
        id = decision.fetch("destination_user_id")
        upload = destination_upload(decision, maps.fetch(:uploads))
        referenced = decision.fetch("choice") != "source" || references.include?([id, upload])
        unless referenced && profiles.fetch(id) == [decision.fetch("username"), upload] &&
                 decision
                   .fetch("sources")
                   .keys
                   .all? { |source| maps.fetch(:users).fetch(source.to_i) == id }
          raise Error, "Matched avatar differs from the reviewed choice for destination user #{id}"
        end
      end
      true
    end
  end
end
