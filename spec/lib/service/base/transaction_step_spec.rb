# frozen_string_literal: true

RSpec.describe Service::Base::TransactionStep do
  describe "#call" do
    subject(:result) { service.call(inner_rollback:) }

    let(:inner_rollback_observer) { spy }
    let(:outer_rollback_observer) { spy }
    let(:inner_rollback) { proc { inner_rollback_observer.call } }
    let(:service) do
      Class.new do
        include Service::Base

        transaction(requires_new: true) { step :fail_transaction }

        private

        def fail_transaction(inner_rollback:)
          ActiveRecord::Base.current_transaction.after_rollback(&inner_rollback)
          raise "transaction failed"
        end
      end
    end

    it "forwards transaction options and scopes rollback callbacks to the savepoint" do
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.current_transaction.after_rollback { outer_rollback_observer.call }

        expect { result }.to raise_error(RuntimeError, "transaction failed")
        expect(inner_rollback_observer).to have_received(:call)
        expect(outer_rollback_observer).not_to have_received(:call)

        raise ActiveRecord::Rollback
      end

      expect(outer_rollback_observer).to have_received(:call)
    end
  end
end
