module StraightServer
  class Thread

    def self.new(label: nil, &block)
      thread         = ::Thread.new(&block)
      thread[:label] = label
      thread
    end

    INTERRUPTION_FLAG = lambda { |label| "#{Config[:'redis.prefix']}:interrupt_thread:#{label}" }

    def self.interrupt(label:)
      redis = StraightServer.redis_connection
      redis.set INTERRUPTION_FLAG[label], Time.now.to_i
    end

    def self.interrupted?(thread:)
      redis  = StraightServer.redis_connection
      result = redis.get(key = INTERRUPTION_FLAG[thread[:label]])
      redis.del key if result
      !!result
    end
  end
end
