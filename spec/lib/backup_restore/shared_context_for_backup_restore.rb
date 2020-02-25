# frozen_string_literal: true
#
shared_context "shared stuff" do
  let!(:logger) do
    Class.new do
      def log(message, ex = nil); end
    end.new
  end
end
