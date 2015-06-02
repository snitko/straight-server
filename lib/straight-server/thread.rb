module StraightServer
  class Thread

    def self.new(label: nil, &block)
      thread         = ::Thread.new(&block)
      thread[:label] = label
      thread
    end

    INTERRUPTION_FLAG = lambda { |label| "#{Config[:'redis.prefix']}:interrupt_thread:#{label}" }

    def self.interrupt(label:)
      return unless (redis = Config[:'redis.connection'])
      redis.set INTERRUPTION_FLAG[label], Time.now.to_i
    end

    def self.interrupted?(thread:)
      return unless (redis = Config[:'redis.connection'])
      result = redis.get(key = INTERRUPTION_FLAG[thread[:label]])
      redis.del key if result
      !!result
    end
  end
end
