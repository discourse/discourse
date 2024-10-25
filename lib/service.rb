# frozen_string_literal: true

module Service
  # Module to be included to provide steps DSL to any class. This allows to
  # create easy to understand services as the whole service cycle is visible
  # simply by reading the beginning of its class.
  #
  # Steps are executed in the order they’re defined. They will use their name
  # to execute the corresponding method defined in the service class.
  #
  # Currently, there are 5 types of steps:
  #
  # * +contract(name = :default)+: used to validate the input parameters,
  #   typically provided by a user calling an endpoint. A block has to be
  #   defined to hold the validations. If the validations fail, the step will
  #   fail. Otherwise, the resulting contract will be available in
  #   +context[:contract]+. When calling +step(name)+ or +model(name = :model)+
  #   methods after validating a contract, the contract should be used as an
  #   argument instead of context attributes.
  # * +model(name = :model)+: used to instantiate a model (either by building
  #   it or fetching it from the DB). If a falsy value is returned, then the
  #   step will fail. Otherwise the resulting object will be assigned in
  #   +context[name]+ (+context[:model]+ by default).
  # * +policy(name = :default)+: used to perform a check on the state of the
  #   system. Typically used to run guardians. If a falsy value is returned,
  #   the step will fail.
  # * +step(name)+: used to run small snippets of arbitrary code. The step
  #   doesn’t care about its return value, so to mark the service as failed,
  #   {#fail!} has to be called explicitly.
  # * +transaction+: used to wrap other steps inside a DB transaction.
  #
  # The methods defined on the service are automatically provided with
  # the whole context passed as keyword arguments. This allows to define in a
  # very explicit way what dependencies are used by the method. If for
  # whatever reason a key isn’t found in the current context, then Ruby will
  # raise an exception when the method is called.
  #
  # Regarding contract classes, they automatically have {ActiveModel} modules
  # included so all the {ActiveModel} API is available.
  #
  # @example An example from the {TrashChannel} service
  #   class TrashChannel
  #     include Service::Base
  #
  #     model :channel
  #     policy :invalid_access
  #     transaction do
  #       step :prevents_slug_collision
  #       step :soft_delete_channel
  #       step :log_channel_deletion
  #     end
  #     step :enqueue_delete_channel_relations_job
  #
  #     private
  #
  #     def fetch_channel(channel_id:)
  #       Chat::Channel.find_by(id: channel_id)
  #     end
  #
  #     def invalid_access(guardian:, channel:)
  #       guardian.can_preview_chat_channel?(channel) && guardian.can_delete_chat_channel?
  #     end
  #
  #     def prevents_slug_collision(channel:)
  #       …
  #     end
  #
  #     def soft_delete_channel(guardian:, channel:)
  #       …
  #     end
  #
  #     def log_channel_deletion(guardian:, channel:)
  #       …
  #     end
  #
  #     def enqueue_delete_channel_relations_job(channel:)
  #       …
  #     end
  #   end
  # @example An example from the {UpdateChannelStatus} service which uses a contract
  #   class UpdateChannelStatus
  #     include Service::Base
  #
  #     model :channel
  #     contract do
  #       attribute :status
  #       validates :status, inclusion: { in: Chat::Channel.editable_statuses.keys }
  #     end
  #     policy :check_channel_permission
  #     step :change_status
  #
  #     …
  #   end
end
