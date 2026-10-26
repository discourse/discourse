# frozen_string_literal: true

RSpec.describe DiscourseVips::WorkerProcess do
  describe "private worker socket" do
    it "is created outside Rails.root so deep checkouts stay under the socket path limit" do
      worker = described_class.new

      expect(worker.socket_path).not_to start_with(Rails.root.to_s)
      expect(worker.socket_path.bytesize).to be < 108
    ensure
      worker&.shutdown
    end
  end
end
