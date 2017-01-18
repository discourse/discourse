module Jobs

  class UpdateGroupMentions < Jobs::Base

    def execute(args)
      group = Group.find_by(id: args[:group_id])
      return unless group

      previous_group_name = args[:previous_name]

      GroupMentionsUpdater.update(group.name, previous_group_name)
    end
  end
end
