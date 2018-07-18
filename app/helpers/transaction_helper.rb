##
# Allows running arbitrary code after the current transaction has been committed.
# Works even with nested transactions. Useful for scheduling sidekiq jobs.
# Slightly simplified version of https://dev.to/evilmartians/rails-aftercommit-everywhere--4j9g
# Usage:
#    Topic.transaction do
#        puts "Some work before scheduling"
#        TransactionHelper.after_commit do
#            puts "Running after commit"
#        end
#        puts "Some work after scheduling"
#    end
#
# Produces:
#     > Some work before scheduling
#     > Some work after scheduling
#     > Running after commit

module TransactionHelper
  class AfterCommitWrapper
    def initialize
      @callback = Proc.new
    end

    def committed!(*)
      @callback.call
    end

    def before_committed!(*); end
    def rolledback!(*); end
  end

  def self.after_commit(&blk)
    ActiveRecord::Base.connection.add_transaction_record(
        AfterCommitWrapper.new(&blk)
    )
  end
end
