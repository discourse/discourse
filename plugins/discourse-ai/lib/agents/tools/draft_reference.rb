# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class DraftReference
        LIFETIME = 1.day
        MAX_PAYLOAD_BYTES = 64.kilobytes

        class ClaimRollback
          def initialize(reference_class:, reference:, reviewable_id:)
            @reference_class = reference_class
            @reference = reference
            @reviewable_id = reviewable_id
          end

          def before_committed!(*args)
          end

          def committed!(*args)
            ActiveRecord::Base.connection.add_transaction_record(self) if DB.transaction_open?
          end

          def rolledback!(*args)
            @reference_class.release(@reference, reviewable_id: @reviewable_id)
          rescue => error
            Discourse.warn_exception(error, message: "failed to release an assistant draft claim")
          end

          def trigger_transactional_callbacks?
            true
          end
        end

        class << self
          def sign(payload, user:)
            serialized =
              payload.deep_stringify_keys.merge(
                "user_id" => user.id,
                "site" => Discourse.current_hostname,
              )
            if JSON.generate(serialized).bytesize > self::MAX_PAYLOAD_BYTES
              raise Discourse::InvalidParameters
            end

            signed = verifier.generate(serialized, expires_in: self::LIFETIME, purpose: purpose)
            reference = "#{reference_prefix}#{SecureRandom.hex(16)}"
            Discourse.redis.setex(draft_key(reference), self::LIFETIME.to_i, signed)
            reference
          end

          def read(reference)
            return if !reference_pattern.match?(reference.to_s)

            signed = Discourse.redis.get(draft_key(reference))
            return if signed.blank?

            verify(signed)
          end

          def read_with_compatibility(reference)
            draft = read(reference)
            draft ||=
              DiscoursePluginRegistry.apply_modifier(
                :admin_assistant_legacy_draft,
                nil,
                draft_kind.to_sym,
                reference,
              )
            draft&.symbolize_keys
          end

          def claim(reference, reviewable_id:)
            return false if !read_with_compatibility(reference)

            value = claim_value(reviewable_id, "creating")
            !!Discourse.redis.set(claim_key(reference), value, nx: true, ex: self::LIFETIME.to_i)
          end

          def complete_after_transaction(reference, reviewable_id:, resource_id:)
            if DB.transaction_open?
              ActiveRecord::Base.connection.add_transaction_record(
                ClaimRollback.new(
                  reference_class: self,
                  reference: reference,
                  reviewable_id: reviewable_id,
                ),
              )
            end

            DB.after_commit do
              complete(reference, reviewable_id: reviewable_id, resource_id: resource_id)
            end
          end

          def release(reference, reviewable_id:)
            expected = claim_value(reviewable_id, "creating")
            Discourse.redis.eval(
              <<~LUA,
                if redis.call("get", KEYS[1]) == ARGV[1] then
                  return redis.call("del", KEYS[1])
                end
                return 0
              LUA
              keys: [Discourse.redis.namespace_key(claim_key(reference))],
              argv: [expected],
            )
          end

          private

          def complete(reference, reviewable_id:, resource_id:)
            expected = claim_value(reviewable_id, "creating")
            value = claim_value(reviewable_id, "created", resource_id: resource_id)
            result =
              Discourse.redis.eval(
                <<~LUA,
                  if redis.call("get", KEYS[1]) == ARGV[1] then
                    redis.call("setex", KEYS[1], ARGV[2], ARGV[3])
                    return 1
                  end
                  return 0
                LUA
                keys: [Discourse.redis.namespace_key(claim_key(reference))],
                argv: [expected, self::LIFETIME.to_i, value],
              )
            raise "assistant draft claim changed before commit" if result != 1
          rescue => error
            Discourse.warn_exception(error, message: "failed to finalize an assistant draft")
          end

          def claim_value(reviewable_id, state, resource_id: nil)
            { reviewable_id: reviewable_id, state: state, resource_id: resource_id }.compact.to_json
          end

          def draft_key(reference)
            "admin-assistant:draft:#{draft_kind}:#{reference}"
          end

          def claim_key(reference)
            "admin-assistant:claim:#{draft_kind}:#{Digest::SHA256.hexdigest(reference.to_s)}"
          end

          def reference_pattern
            /\A#{Regexp.escape(reference_prefix)}[0-9a-f]{32}\z/
          end

          def verify(signed)
            draft = verifier.verified(signed, purpose: purpose)
            return unless draft.is_a?(Hash) && draft["site"] == Discourse.current_hostname

            draft.symbolize_keys
          end

          def verifier
            Rails.application.message_verifier("admin-assistant-#{draft_kind}")
          end

          def draft_kind
            raise NotImplementedError
          end

          def purpose
            "admin_assistant_#{draft_kind}"
          end

          def reference_prefix
            "#{draft_kind}_draft_"
          end
        end
      end
    end
  end
end
