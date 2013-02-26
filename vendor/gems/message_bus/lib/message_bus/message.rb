class MessageBus::Message < Struct.new(:global_id, :message_id, :channel , :data)

  attr_accessor :site_id, :user_ids

  def self.decode(encoded)
    s1 = encoded.index("|")
    s2 = encoded.index("|", s1+1)
    s3 = encoded.index("|", s2+1)

    MessageBus::Message.new encoded[0..s1].to_i, encoded[s1+1..s2].to_i, encoded[s2+1..s3-1].gsub("$$123$$", "|"), encoded[s3+1..-1]
  end

  # only tricky thing to encode is pipes in a channel name ... do a straight replace
  def encode
    global_id.to_s << "|" << message_id.to_s << "|" << channel.gsub("|","$$123$$") << "|" << data
  end
end
